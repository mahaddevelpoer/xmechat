import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<UserModel> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _loading = true);
    try {
      final uid = ref.read(authServiceProvider).currentUserId;
      final db = Supabase.instance.client;

      // Get blocked user IDs
      final blocked = await db.from(SupabaseConstants.blockedUsersTable)
          .select('blocked_user_id')
          .eq('user_id', uid);

      if (blocked.isEmpty) {
        if (mounted) setState(() { _blockedUsers = []; _loading = false; });
        return;
      }

      final blockedIds = blocked.map((b) => b['blocked_user_id'] as String).toList();

      // Fetch user details for blocked users
      final users = await db.from(SupabaseConstants.usersTable)
          .select()
          .inFilter('id', blockedIds);

      if (mounted) {
        setState(() {
          _blockedUsers = users.map<UserModel>((m) => UserModel.fromMap(m)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading blocked users: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _unblockUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Unblock ${user.name}? They will be able to send you messages again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(chatServiceProvider).unblockUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} unblocked'),
            backgroundColor: AppColors.primaryGreen));
        _loadBlockedUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: const Text('Blocked Contacts', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
        : _blockedUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: AppColors.textHint.withAlpha(80)),
                  const SizedBox(height: 16),
                  const Text('No blocked contacts',
                    style: TextStyle(fontSize: 16, color: AppColors.textHint)),
                  const SizedBox(height: 8),
                  const Text('Blocked contacts will appear here',
                    style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _blockedUsers.length,
              itemBuilder: (_, i) {
                final user = _blockedUsers[i];
                return Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: UserAvatar(url: user.avatarUrl, name: user.name, radius: 22),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(user.bio.isNotEmpty ? user.bio : user.email,
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: TextButton.icon(
                      onPressed: () => _unblockUser(user),
                      icon: const Icon(Icons.block, size: 18, color: AppColors.error),
                      label: const Text('Unblock', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

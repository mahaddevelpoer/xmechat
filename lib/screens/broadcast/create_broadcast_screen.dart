import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/add_group_member_sheet.dart';

class CreateBroadcastScreen extends ConsumerStatefulWidget {
  const CreateBroadcastScreen({super.key});
  @override
  ConsumerState<CreateBroadcastScreen> createState() => _CreateBroadcastScreenState();
}

class _CreateBroadcastScreenState extends ConsumerState<CreateBroadcastScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _loading = false;

  Future<void> _addMember() async {
    final user = await showDialog<UserModel?>(
      context: context,
      builder: (_) => const AddGroupMemberSheet(),
    );
    if (user == null || !mounted) return;
    setState(() => _selectedIds.add(user.id));
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a list name')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one recipient')));
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await ref.read(broadcastServiceProvider).createList(
        name: _nameCtrl.text.trim(),
        memberIds: _selectedIds.toList(),
      );
      ref.invalidate(broadcastListsProvider);
      if (!mounted) return;
      context.pushReplacement('/broadcast-chat/${list.id}', extra: list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('New Broadcast List')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'List name',
              hintStyle: TextStyle(color: AppColors.textHint),
              border: InputBorder.none,
              filled: false,
            ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Container(
            height: 60, color: Colors.white,
            child: usersAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (users) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: users.where((u) => _selectedIds.contains(u.id)).map((u) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: UserAvatar(url: u.avatarUrl, name: u.name, radius: 12),
                      label: Text(u.name.split(' ').first),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _selectedIds.remove(u.id)),
                    ),
                  )
                ).toList(),
              ),
            ),
          ),
        Expanded(child: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (users) => ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) {
              final u = users[i];
              final selected = _selectedIds.contains(u.id);
              return ListTile(
                leading: UserAvatar(url: u.avatarUrl, name: u.name, radius: 22),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(u.email,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: selected
                  ? const CircleAvatar(radius: 12, backgroundColor: AppColors.accentGreen,
                      child: Icon(Icons.check, size: 14, color: Colors.white))
                  : null,
                onTap: () => setState(() {
                  selected ? _selectedIds.remove(u.id) : _selectedIds.add(u.id);
                }),
              );
            },
          ),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add by email/phone'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_loading
                  ? 'Creating...'
                  : 'Create List (${_selectedIds.length} recipients)'),
            ),
          ),
        ),
      ]),
    );
  }
}

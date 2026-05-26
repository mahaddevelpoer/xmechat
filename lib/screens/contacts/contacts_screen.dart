import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/chat_service.dart';
import '../../models/models.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<UserModel> _users = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  late final String _myId;
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _chatService = ChatService(_myId);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _chatService.getAllUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<UserModel> get _filtered {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) =>
      u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      u.email.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _openChat(UserModel user) async {
    final chatId = await _chatService.getOrCreateChat(user.id);
    if (mounted) Navigator.pushNamed(context, '/chat/$chatId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingWidget(message: 'Loading contacts...');
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? 'No contacts found' : 'No other users yet',
          style: AppText.preview,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final user = items[i];
          return ListTile(
            leading: UserAvatar(
              imageUrl: user.avatarUrl,
              name: user.name,
              showOnline: true,
              isOnline: user.isOnline,
            ),
            title: Text(user.name, style: AppText.name),
            subtitle: Text(user.email, style: AppText.preview),
            trailing: const Icon(Icons.chat_outlined, size: 20, color: AppColors.accent),
            onTap: () => _openChat(user),
          );
        },
      ),
    );
  }
}

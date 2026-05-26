import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/group_service.dart';
import '../../services/chat_service.dart';
import '../../models/models.dart';
import '../../widgets/common/user_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<UserModel> _allUsers = [];
  final Set<String> _selectedIds = {};
  Uint8List? _iconBytes;
  bool _loading = false;
  bool _usersLoading = true;
  String _searchQuery = '';
  late final String _myId;
  late final ChatService _chatService;
  late final GroupService _groupService;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _chatService = ChatService(_myId);
    _groupService = GroupService(_myId);
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _chatService.getAllUsers();
      if (mounted) setState(() { _allUsers = users; _usersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _pickIcon() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [XTypeGroup(extensions: ['jpg', 'jpeg', 'png'])],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _iconBytes = bytes);
      }
    } catch (_) {}
  }

  List<UserModel> get _filtered {
    if (_searchQuery.isEmpty) return _allUsers;
    return _allUsers.where((u) =>
      u.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name and select members')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _groupService.createGroup(
        name: name,
        description: _descCtrl.text.trim(),
        memberIds: _selectedIds.toList(),
        iconBytes: _iconBytes,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('New Group'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _create,
            child: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickIcon,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.accentLight,
                    child: _iconBytes != null
                        ? ClipOval(child: Image.memory(_iconBytes!, width: 64, height: 64, fit: BoxFit.cover))
                        : Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Group Name', hintText: 'Enter group name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.accentLight,
              child: Row(
                children: [
                  Text('${_selectedIds.length} selected', style: AppText.label.copyWith(color: AppColors.accent)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_usersLoading) return const Center(child: CircularProgressIndicator());
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Text(_searchQuery.isNotEmpty ? 'No users found' : 'No users', style: AppText.preview));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final user = items[i];
        final selected = _selectedIds.contains(user.id);
        return CheckboxListTile(
          value: selected,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _selectedIds.add(user.id);
              } else {
                _selectedIds.remove(user.id);
              }
            });
          },
          secondary: UserAvatar(imageUrl: user.avatarUrl, name: user.name),
          title: Text(user.name, style: AppText.name),
          subtitle: Text(user.email, style: AppText.preview),
        );
      },
    );
  }
}

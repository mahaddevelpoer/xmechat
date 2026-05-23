import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _selectedIds = {};
  Uint8List? _iconBytes;
  bool _loading = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await ref.read(chatServiceProvider).getAllUsers();
      if (mounted) setState(() { _allUsers = users; _filteredUsers = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = q.isEmpty
          ? _allUsers
          : _allUsers.where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _pickIcon() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _iconBytes = bytes);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name is required')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one member')));
      return;
    }
    setState(() => _creating = true);
    try {
      await ref.read(groupServiceProvider).createGroup(
        name: name,
        description: _descCtrl.text.trim(),
        memberIds: _selectedIds.toList(),
        iconBytes: _iconBytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created')));
        context.canPop() ? context.pop() : context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text('Create Group', style: AppText.title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _creating ? null : _createGroup,
              child: _creating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Create', style: AppText.link),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: Stack(
                  children: [
                    UserAvatar(
                      imageUrl: null,
                      name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'G',
                      size: 80,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: AppText.body,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Enter group name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: AppText.body,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this group about?',
              ),
            ),
            const SizedBox(height: 20),
            Text('Add Members (${_selectedIds.length} selected)', style: AppText.title),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: AppText.hint,
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const LoadingWidget()
            else if (_filteredUsers.isEmpty)
              const EmptyState(icon: Icons.people_outline, title: 'No users found')
            else
              ..._filteredUsers.map((u) => CheckboxListTile(
                dense: true,
                value: _selectedIds.contains(u.id),
                onChanged: (v) {
                  setState(() {
                    if (v == true) _selectedIds.add(u.id);
                    else _selectedIds.remove(u.id);
                  });
                },
                secondary: UserAvatar(imageUrl: u.avatarUrl, name: u.name, size: 36),
                title: Text(u.name, style: AppText.body),
                subtitle: Text(u.email, style: AppText.caption),
              )),
          ],
        ),
      ),
    );
  }
}

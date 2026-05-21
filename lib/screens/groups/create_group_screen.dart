import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/add_group_member_sheet.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Uint8List? _iconBytes;
  final Set<String> _selectedIds = {};
  bool _loading = false;

  Future<void> _addMemberByEmailOrPhone() async {
    final user = await showDialog<UserModel?>(
      context: context,
      builder: (_) => const AddGroupMemberSheet(),
    );
    if (user == null) return;
    setState(() => _selectedIds.add(user.id));
  }

  Future<void> _pickIcon() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes != null) {
        setState(() => _iconBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error picking icon: $e');
    }
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a group name')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one member')));
      return;
    }
    setState(() => _loading = true);
    try {
      final group = await ref.read(groupServiceProvider).createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        memberIds: _selectedIds.toList(),
        iconBytes: _iconBytes,
      );
      ref.invalidate(groupsProvider);
      if (!mounted) return;
      context.pushReplacement('/group-chat/${group.id}', extra: {'group': group});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('New Group')),
      body: Column(children: [
        // Group info section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            GestureDetector(
              onTap: _pickIcon,
              child: CircleAvatar(
                radius: 30, backgroundColor: AppColors.bgSecondary,
                backgroundImage: _iconBytes != null ? MemoryImage(_iconBytes!) : null,
                child: _iconBytes == null ? const Icon(Icons.camera_alt, color: AppColors.textHint, size: 28) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                  filled: false,
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              const Divider(height: 1),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  hintText: 'Group description (optional)',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ])),
          ]),
        ),
        // Selected members chips
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
        // User list
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
                subtitle: Text(u.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
        // Add member via email/phone (required)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMemberByEmailOrPhone,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add member by email/phone'),
            ),
          ),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            label: _loading ? 'Creating...' : 'Create Group (${_selectedIds.length} selected)',
            loading: _loading,
            onPressed: _create,
          ),
        ),
      ]),
    );
  }
}

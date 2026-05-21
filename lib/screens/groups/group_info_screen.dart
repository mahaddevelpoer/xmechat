import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/add_group_member_sheet.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupInfoScreen({super.key, required this.groupId});
  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  List<GroupMemberModel> _members = [];
  GroupModel? _group;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await ref.read(groupServiceProvider).fetchMembers(widget.groupId);
    final groups = await ref.read(groupServiceProvider).fetchMyGroups();
    final isAdmin = await ref.read(groupServiceProvider).isAdmin(widget.groupId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _group = groups.firstWhere((g) => g.id == widget.groupId, orElse: () => GroupModel(id: widget.groupId, name: 'Group', createdBy: '', lastMessageAt: DateTime.now(), createdAt: DateTime.now()));
      _isAdmin = isAdmin;
    });
  }

  Future<void> _addMember() async {
    final user = await showDialog<UserModel?>(
      context: context,
      builder: (_) => const AddGroupMemberSheet(),
    );
    if (user == null) return;
    await ref.read(groupServiceProvider).addMembers(widget.groupId, [user.id]);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200, pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _group?.iconUrl.isNotEmpty == true
              ? Image.network(_group!.iconUrl, fit: BoxFit.cover)
              : Container(color: AppColors.accentGreen,
                  child: const Icon(Icons.group, size: 80, color: Colors.white54)),
          ),
        ),
        SliverToBoxAdapter(child: Column(children: [
          Container(color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_group?.name ?? 'Group', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (_group?.description.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(_group!.description, style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 6),
              Text('Created ${_timeAgo(_group?.createdAt ?? DateTime.now())}',
                style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('${_members.length} participants',
                  style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
              ),
              if (_isAdmin)
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.person_add, color: Colors.white),
                  ),
                  title: const Text('Add Members', style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w500)),
                  onTap: _addMember,
                ),
              ..._members.map((m) => ListTile(
                leading: UserAvatar(url: m.user?.avatarUrl, name: m.user?.name ?? '?', radius: 22),
                title: Row(children: [
                  Text(m.user?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (m.isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withAlpha(20),
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('Admin', style: TextStyle(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                subtitle: Text(m.user?.bio.isEmpty == true ? m.user?.email ?? '' : m.user?.bio ?? '',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: _isAdmin
                  ? PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'make_admin') await ref.read(groupServiceProvider).toggleAdmin(widget.groupId, m.userId, true);
                        if (v == 'remove_admin') await ref.read(groupServiceProvider).toggleAdmin(widget.groupId, m.userId, false);
                        if (v == 'remove') { await ref.read(groupServiceProvider).removeMember(widget.groupId, m.userId); }
                        ref.invalidate(groupsProvider);
                        _load();
                      },
                      itemBuilder: (_) => [
                        if (!m.isAdmin) const PopupMenuItem(value: 'make_admin', child: Text('Make Admin')),
                        if (m.isAdmin) const PopupMenuItem(value: 'remove_admin', child: Text('Remove Admin')),
                        const PopupMenuItem(value: 'remove', child: Text('Remove from group', style: TextStyle(color: AppColors.error))),
                      ],
                    )
                  : null,
              )),
            ]),
          ),
          const SizedBox(height: 8),
          Container(color: Colors.white, child: Column(children: [
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: AppColors.error),
              title: const Text('Leave Group', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                await ref.read(groupServiceProvider).leaveGroup(widget.groupId);
                ref.invalidate(groupsProvider);
                if (!context.mounted) return;
                context.go('/home');
              },
            ),
          ])),
          const SizedBox(height: 30),
        ])),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    return 'recently';
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/broadcast_service.dart';
import '../../models/models.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_widget.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  List<BroadcastListModel> _lists = [];
  bool _loading = true;
  late final String _myId;
  late final BroadcastService _broadcastService;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _broadcastService = BroadcastService(_myId);
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await _broadcastService.fetchMyLists();
      if (mounted) setState(() { _lists = lists; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createList() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Broadcast List'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'List Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await _broadcastService.createList(name: name, memberIds: []);
      await _loadLists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _deleteList(BroadcastListModel list) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Delete "${list.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _broadcastService.deleteList(list.id);
      await _loadLists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showMembers(BroadcastListModel list) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BroadcastMembersScreen(list: list, broadcastService: _broadcastService),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Broadcast Lists'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createList),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : _lists.isEmpty
              ? EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No Broadcast Lists',
                  subtitle: 'Create lists to send messages to multiple contacts',
                  actionLabel: 'Create List',
                  onAction: _createList,
                )
              : RefreshIndicator(
                  onRefresh: _loadLists,
                  child: ListView.builder(
                    itemCount: _lists.length,
                    itemBuilder: (_, i) {
                      final list = _lists[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentLight,
                          child: Icon(Icons.campaign_outlined, color: AppColors.accent),
                        ),
                        title: Text(list.name, style: AppText.name),
                        subtitle: Text('${list.members.length} members', style: AppText.preview),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'members') _showMembers(list);
                            if (v == 'delete') _deleteList(list);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'members', child: Text('Manage Members')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _BroadcastMembersScreen extends StatefulWidget {
  final BroadcastListModel list;
  final BroadcastService broadcastService;
  const _BroadcastMembersScreen({required this.list, required this.broadcastService});

  @override
  State<_BroadcastMembersScreen> createState() => _BroadcastMembersScreenState();
}

class _BroadcastMembersScreenState extends State<_BroadcastMembersScreen> {
  late List<UserModel> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.list.members;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.list.name} Members'),
        backgroundColor: AppColors.surface,
      ),
      body: _members.isEmpty
          ? const Center(child: Text('No members yet'))
          : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (_, i) {
                final m = _members[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentLight,
                    child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.accent)),
                  ),
                  title: Text(m.name, style: AppText.name),
                  subtitle: Text(m.email, style: AppText.preview),
                );
              },
            ),
    );
  }
}

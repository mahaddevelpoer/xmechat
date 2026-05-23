import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  bool _showCreate = false;
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _selectedIds = {};
  bool _loadingUsers = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _searchUsers(String q) {
    setState(() {
      _filteredUsers = q.isEmpty
          ? _allUsers
          : _allUsers.where((u) =>
              u.name.toLowerCase().contains(q.toLowerCase()) ||
              u.email.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await ref.read(chatServiceProvider).getAllUsers();
      if (mounted) setState(() { _allUsers = users; _filteredUsers = users; _loadingUsers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _createList() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List name is required')));
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one recipient')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(broadcastServiceProvider).createList(
        name: name,
        memberIds: _selectedIds.toList(),
      );
      if (mounted) {
        setState(() { _showCreate = false; _nameCtrl.clear(); _selectedIds.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast list created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteList(String listId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete list?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(broadcastServiceProvider).deleteList(listId);
      if (mounted) ref.invalidate(broadcastListsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(broadcastListsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text('Broadcast Lists', style: AppText.title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: _showCreate ? _buildCreateView() : _buildListView(listsAsync),
    );
  }

  Widget _buildListView(AsyncValue<List<BroadcastListModel>> listsAsync) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _showCreate = true);
                _loadUsers();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Broadcast List'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: listsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => ErrorState(error: e),
            data: (lists) {
              if (lists.isEmpty) {
                return const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No broadcast lists',
                  subtitle: 'Create a list to send messages to multiple contacts at once',
                );
              }
              return ListView.builder(
                itemCount: lists.length,
                itemBuilder: (_, i) {
                  final list = lists[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined, color: AppColors.accent),
                      title: Text(list.name, style: AppText.name),
                      subtitle: Text('${list.members.length} recipients', style: AppText.bodyGrey),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        onPressed: () => _deleteList(list.id),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => _BroadcastSendDialog(list: list),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            style: AppText.body,
            decoration: const InputDecoration(labelText: 'List name', hintText: 'e.g. Family, Work Team'),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: _searchUsers,
            controller: _searchCtrl,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: AppText.hint,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textHint),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text('${_selectedIds.length} selected', style: AppText.bodyGrey),
          if (_loadingUsers)
            const LoadingWidget()
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _showCreate = false; _nameCtrl.clear(); _selectedIds.clear(); }),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _createList,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Text('Create List'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BroadcastSendDialog extends ConsumerStatefulWidget {
  final BroadcastListModel list;
  const _BroadcastSendDialog({required this.list});

  @override
  ConsumerState<_BroadcastSendDialog> createState() => _BroadcastSendDialogState();
}

class _BroadcastSendDialogState extends ConsumerState<_BroadcastSendDialog> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(broadcastServiceProvider).sendBroadcastMessage(
        listId: widget.list.id,
        text: text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast sent')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send to ${widget.list.name}', style: AppText.title),
            Text('${widget.list.members.length} recipients', style: AppText.bodyGrey),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              style: AppText.body,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your broadcast message...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                    : const Text('Send Broadcast'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

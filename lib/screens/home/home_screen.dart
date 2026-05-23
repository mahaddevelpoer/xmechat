// ─────────────────────────────────────────────────────
// home_screen.dart  — 3-panel desktop shell
// ─────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';

// ─────────────────────────────────────────────────────
// ROOT
// ─────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0; // 0=Chats 1=Groups 2=Status 3=Settings

  // Chats state
  ChatModel? _selectedChat;
  List<ChatModel> _chats = [];
  bool _chatsLoading = true;
  String _chatSearch = '';
  RealtimeChannel? _channel;

  // Groups state
  GroupModel? _selectedGroup;
  List<GroupModel> _groups = [];
  bool _groupsLoading = false;

  // Status state
  List<StatusModel> _statuses = [];
  StatusModel? _selectedStatus;
  bool _statusLoading = false;

  // Settings state
  int _settingsPage = 0;

  // Current user
  UserModel? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadChats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────
  Future<void> _loadMe() async {
    final u = await AuthService().getCurrentUserProfile();
    if (mounted) setState(() => _me = u);
  }

  Future<void> _loadChats() async {
    setState(() => _chatsLoading = true);
    try {
      final list = await ref.read(chatServiceProvider).fetchChats();
      if (mounted) setState(() { _chats = list; _chatsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _chatsLoading = false);
    }
  }

  void _subscribeRealtime() {
    final uid = ref.read(currentUserIdProvider);
    _channel = Supabase.instance.client
        .channel('home-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _loadChats(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _loadChats(),
        )
        .subscribe();
  }

  Future<void> _loadGroups() async {
    if (_groupsLoading) return;
    setState(() => _groupsLoading = true);
    try {
      final list = await ref.read(groupServiceProvider).fetchMyGroups();
      if (mounted) setState(() { _groups = list; _groupsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  Future<void> _loadStatuses() async {
    if (_statusLoading) return;
    setState(() => _statusLoading = true);
    try {
      final list = await ref.read(statusServiceProvider).fetchAllStatuses();
      if (mounted) setState(() { _statuses = list; _statusLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  void _selectTab(int t) {
    setState(() {
      _tab = t;
      _selectedChat = null;
      _selectedGroup = null;
      _selectedStatus = null;
    });
    if (t == 1 && _groups.isEmpty) _loadGroups();
    if (t == 2) _loadStatuses();
  }

  List<ChatModel> get _filteredChats {
    if (_chatSearch.isEmpty) return _chats;
    final q = _chatSearch.toLowerCase();
    return _chats.where((c) =>
        (c.otherUser?.name.toLowerCase().contains(q) ?? false) ||
        c.lastMessage.toLowerCase().contains(q)).toList();
  }

  // ── Build ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(incomingCallProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Row(
            children: [
              _Sidebar(tab: _tab, me: _me, onTab: _selectTab, onLogout: _logout),
              const VerticalDivider(width: 1, thickness: 1),
              SizedBox(
                width: AppSizes.chatListWidth,
                child: _buildListPanel(),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: _buildMainPanel()),
            ],
          ),
          if (incoming.valueOrNull != null)
            _IncomingCallOverlay(call: incoming.value!),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  // ── Panel B dispatcher ──────────────────────────────
  Widget _buildListPanel() {
    switch (_tab) {
      case 1:
        return _GroupsListPanel(
          groups: _groups,
          loading: _groupsLoading,
          selected: _selectedGroup,
          onSelect: (g) => setState(() => _selectedGroup = g),
          onCreateGroup: () => context.push('/create-group'),
          onRefresh: _loadGroups,
        );
      case 2:
        return _StatusListPanel(
          statuses: _statuses,
          loading: _statusLoading,
          selected: _selectedStatus,
          onSelect: (s) => setState(() => _selectedStatus = s),
          onCreateStatus: () => context.push('/create-status'),
          me: _me,
        );
      case 3:
        return _SettingsNavPanel(
          selectedPage: _settingsPage,
          me: _me,
          onSelect: (i) => setState(() => _settingsPage = i),
        );
      default:
        return _ChatsListPanel(
          chats: _filteredChats,
          loading: _chatsLoading,
          selected: _selectedChat,
          search: _chatSearch,
          onSearch: (q) => setState(() => _chatSearch = q),
          onSelect: (c) => setState(() => _selectedChat = c),
          onNewChat: () => _showAddContact(context),
        );
    }
  }

  // ── Panel C dispatcher ──────────────────────────────
  Widget _buildMainPanel() {
    switch (_tab) {
      case 1:
        if (_selectedGroup != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.push('/group-chat/${_selectedGroup!.id}',
                extra: {'group': _selectedGroup});
            setState(() => _selectedGroup = null);
          });
        }
        return const NoChatSelected();
      case 2:
        return _selectedStatus != null
            ? _StatusViewer(
                status: _selectedStatus!,
                onClose: () => setState(() => _selectedStatus = null),
              )
            : const EmptyState(
                icon: Icons.circle_outlined,
                title: 'Status Updates',
                subtitle: 'Select a status to view it',
              );
      case 3:
        return _SettingsDetailPanel(
          page: _settingsPage,
          me: _me,
          onProfileUpdated: _loadMe,
          onLogout: _logout,
        );
      default:
        if (_selectedChat == null) return const NoChatSelected();
        return _InlineChatPanel(
          key: ValueKey(_selectedChat!.id),
          chat: _selectedChat!,
          onBack: () => setState(() => _selectedChat = null),
        );
    }
  }

  void _showAddContact(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _AddContactDialog(
        onChatOpened: (chat) {
          setState(() {
            _selectedChat = chat;
            _tab = 0;
          });
          _loadChats();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// SIDEBAR (Panel A — 56px)
// ─────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int tab;
  final UserModel? me;
  final ValueChanged<int> onTab;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.tab,
    required this.me,
    required this.onTab,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.sidebarWidth,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // App icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_rounded,
                  color: AppColors.white, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF2A3C28), height: 1),
          const SizedBox(height: 8),
          _SideIcon(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chats',
            selected: tab == 0,
            onTap: () => onTab(0),
          ),
          _SideIcon(
            icon: Icons.group_outlined,
            label: 'Groups',
            selected: tab == 1,
            onTap: () => onTab(1),
          ),
          _SideIcon(
            icon: Icons.circle_outlined,
            label: 'Status',
            selected: tab == 2,
            onTap: () => onTab(2),
          ),
          const Spacer(),
          _SideIcon(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: tab == 3,
            onTap: () => onTab(3),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: me?.name ?? 'My Profile',
            preferBelow: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UserAvatar(
                imageUrl: me?.avatarUrl,
                name: me?.name ?? 'Me',
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? AppColors.white : AppColors.sidebarIcon,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// CHATS LIST PANEL (Panel B — tab 0)
// ─────────────────────────────────────────────────────
class _ChatsListPanel extends StatelessWidget {
  final List<ChatModel> chats;
  final bool loading;
  final ChatModel? selected;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<ChatModel> onSelect;
  final VoidCallback onNewChat;

  const _ChatsListPanel({
    required this.chats,
    required this.loading,
    required this.selected,
    required this.search,
    required this.onSearch,
    required this.onSelect,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          // Header
          SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Chats', style: AppText.title),
                  const Spacer(),
                  Tooltip(
                    message: 'New Chat',
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onNewChat,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Search
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: onSearch,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: AppText.hint,
                prefixIcon: const Icon(Icons.search, size: 18,
                    color: AppColors.textHint),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.bg,
              ),
            ),
          ),
          // List
          Expanded(
            child: loading
                ? const LoadingWidget(label: 'Loading chats...')
                : chats.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: search.isNotEmpty
                            ? 'No results for "$search"'
                            : 'No chats yet',
                        subtitle: search.isEmpty
                            ? 'Tap the pencil icon to start a conversation'
                            : null,
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (_, i) => _ChatListItem(
                          chat: chats[i],
                          isSelected: selected?.id == chats[i].id,
                          onTap: () => onSelect(chats[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final ChatModel chat;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }

  String _lastMessagePreview() {
    if (chat.lastMessage.isEmpty) return 'No messages yet';
    switch (chat.lastMessageType) {
      case 'audio': return '🎵 Voice note';
      case 'image': return '📷 Photo';
      case 'video': return '🎥 Video';
      case 'document': return '📄 Document';
      case 'location': return '📍 Location';
      default: return chat.lastMessage;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = chat.otherUser;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: AppSizes.chatItemHeight,
        color: isSelected ? AppColors.accentLight : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: other?.avatarUrl,
              name: other?.name ?? '?',
              size: AppSizes.avatarMd,
              showOnline: true,
              isOnline: other?.isOnline ?? false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          other?.name ?? 'Unknown',
                          style: AppText.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessageAt),
                        style: AppText.timestamp,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastMessagePreview(),
                          style: AppText.bodyGrey,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: AppText.timestamp.copyWith(
                                color: AppColors.white, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// GROUPS LIST PANEL (Panel B — tab 1)
// ─────────────────────────────────────────────────────
class _GroupsListPanel extends StatelessWidget {
  final List<GroupModel> groups;
  final bool loading;
  final GroupModel? selected;
  final ValueChanged<GroupModel> onSelect;
  final VoidCallback onCreateGroup;
  final VoidCallback onRefresh;

  const _GroupsListPanel({
    required this.groups,
    required this.loading,
    required this.selected,
    required this.onSelect,
    required this.onCreateGroup,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Groups', style: AppText.title),
                  const Spacer(),
                  Tooltip(
                    message: 'New Group',
                    child: IconButton(
                      icon: const Icon(Icons.group_add_outlined, size: 20),
                      onPressed: onCreateGroup,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const LoadingWidget(label: 'Loading groups...')
                : groups.isEmpty
                    ? EmptyState(
                        icon: Icons.group_outlined,
                        title: 'No groups yet',
                        subtitle: 'Create a group to chat with multiple people',
                        actionLabel: 'Create Group',
                        onAction: onCreateGroup,
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (_, i) {
                          final g = groups[i];
                          return InkWell(
                            onTap: () => onSelect(g),
                            child: Container(
                              height: AppSizes.chatItemHeight,
                              color: selected?.id == g.id
                                  ? AppColors.accentLight
                                  : Colors.transparent,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    imageUrl: g.iconUrl.isNotEmpty
                                        ? g.iconUrl
                                        : null,
                                    name: g.name,
                                    size: AppSizes.avatarMd,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(g.name,
                                            style: AppText.name,
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                          g.lastMessage.isEmpty
                                              ? 'No messages'
                                              : g.lastMessage,
                                          style: AppText.bodyGrey,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// STATUS LIST PANEL (Panel B — tab 2)
// ─────────────────────────────────────────────────────
class _StatusListPanel extends StatelessWidget {
  final List<StatusModel> statuses;
  final bool loading;
  final StatusModel? selected;
  final ValueChanged<StatusModel> onSelect;
  final VoidCallback onCreateStatus;
  final UserModel? me;

  const _StatusListPanel({
    required this.statuses,
    required this.loading,
    required this.selected,
    required this.onSelect,
    required this.onCreateStatus,
    required this.me,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Status', style: AppText.title),
                  const Spacer(),
                  Tooltip(
                    message: 'Add Status',
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: onCreateStatus,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // My status
          InkWell(
            onTap: onCreateStatus,
            child: Container(
              height: AppSizes.chatItemHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                          imageUrl: me?.avatarUrl,
                          name: me?.name ?? 'Me',
                          size: AppSizes.avatarMd),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.add,
                              size: 12, color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Status', style: AppText.name),
                        Text('Tap to add a status update',
                            style: AppText.bodyGrey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Updates',
                  style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
          ),
          Expanded(
            child: loading
                ? const LoadingWidget()
                : statuses.isEmpty
                    ? const EmptyState(
                        icon: Icons.circle_outlined,
                        title: 'No status updates',
                        subtitle: 'Status updates from your contacts appear here',
                      )
                    : ListView.builder(
                        itemCount: statuses.length,
                        itemBuilder: (_, i) {
                          final s = statuses[i];
                          return InkWell(
                            onTap: () => onSelect(s),
                            child: Container(
                              height: AppSizes.chatItemHeight,
                              color: selected?.id == s.id
                                  ? AppColors.accentLight
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: AppSizes.avatarMd,
                                    height: AppSizes.avatarMd,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: s.viewedByMe
                                            ? AppColors.border
                                            : AppColors.accent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: UserAvatar(
                                        imageUrl: s.user?.avatarUrl,
                                        name: s.user?.name ?? '?',
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.user?.name ?? 'Unknown',
                                            style: AppText.name,
                                            overflow:
                                                TextOverflow.ellipsis),
                                        Text(
                                          DateFormat('h:mm a')
                                              .format(s.createdAt),
                                          style: AppText.bodyGrey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// STATUS VIEWER (Panel C — tab 2)
// ─────────────────────────────────────────────────────
class _StatusViewer extends StatelessWidget {
  final StatusModel status;
  final VoidCallback onClose;

  const _StatusViewer({required this.status, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Progress bar + header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: Colors.white24,
                    color: AppColors.white,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    UserAvatar(
                        imageUrl: status.user?.avatarUrl,
                        name: status.user?.name ?? '?',
                        size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.user?.name ?? 'Unknown',
                              style: AppText.name
                                  .copyWith(color: AppColors.white)),
                          Text(
                            DateFormat('h:mm a').format(status.createdAt),
                            style: AppText.timestamp
                                .copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.white),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Center(
              child: status.type == 'image' && status.contentUrl.isNotEmpty
                  ? Image.network(status.contentUrl, fit: BoxFit.contain)
                  : Container(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        status.text.isNotEmpty ? status.text : '(No text)',
                        style: AppText.heading
                            .copyWith(color: AppColors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
          // Reply bar
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: AppText.body.copyWith(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: 'Reply to status...',
                      hintStyle: AppText.hint
                          .copyWith(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.accent),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// SETTINGS NAV PANEL (Panel B — tab 3)
// ─────────────────────────────────────────────────────
class _SettingsNavPanel extends StatelessWidget {
  final int selectedPage;
  final UserModel? me;
  final ValueChanged<int> onSelect;

  const _SettingsNavPanel({
    required this.selectedPage,
    required this.me,
    required this.onSelect,
  });

  static const _pages = [
    (Icons.person_outline, 'Profile'),
    (Icons.notifications_outlined, 'Notifications'),
    (Icons.chat_bubble_outline, 'Chats'),
    (Icons.call_outlined, 'Calls'),
    (Icons.lock_outlined, 'Account & Privacy'),
    (Icons.info_outlined, 'About'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Settings', style: AppText.title),
              ),
            ),
          ),
          const Divider(height: 1),
          // Profile card
          InkWell(
            onTap: () => onSelect(0),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: selectedPage == 0
                  ? AppColors.accentLight
                  : Colors.transparent,
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: me?.avatarUrl,
                    name: me?.name ?? 'Me',
                    size: AppSizes.avatarLg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me?.name ?? 'My Profile',
                            style: AppText.name,
                            overflow: TextOverflow.ellipsis),
                        Text('Edit profile',
                            style:
                                AppText.link.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Nav items
          Expanded(
            child: ListView.builder(
              itemCount: _pages.length,
              itemBuilder: (_, i) {
                final (icon, label) = _pages[i];
                return InkWell(
                  onTap: () => onSelect(i),
                  child: Container(
                    height: 46,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    color: selectedPage == i
                        ? AppColors.accentLight
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(icon,
                            size: 18,
                            color: selectedPage == i
                                ? AppColors.accent
                                : AppColors.textGrey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: AppText.body.copyWith(
                              color: selectedPage == i
                                  ? AppColors.accent
                                  : AppColors.textDark,
                              fontWeight: selectedPage == i
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textHint),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// SETTINGS DETAIL (Panel C — tab 3)
// ─────────────────────────────────────────────────────
class _SettingsDetailPanel extends StatefulWidget {
  final int page;
  final UserModel? me;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLogout;

  const _SettingsDetailPanel({
    required this.page,
    required this.me,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<_SettingsDetailPanel> createState() => _SettingsDetailPanelState();
}

class _SettingsDetailPanelState extends State<_SettingsDetailPanel> {
  // Notification settings
  bool _msgNotif = true;
  bool _callNotif = true;
  bool _groupNotif = true;
  bool _soundEnabled = true;
  bool _vibration = true;

  // Chat settings
  bool _enterToSend = false;
  double _fontSize = 14.0;
  bool _mediaAutoDownload = true;

  // Privacy
  bool _readReceipts = true;
  bool _onlineStatus = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _msgNotif = prefs.getBool('notif_messages') ?? true;
      _callNotif = prefs.getBool('notif_calls') ?? true;
      _groupNotif = prefs.getBool('notif_groups') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      _vibration = prefs.getBool('notif_vibration') ?? true;
      _enterToSend = prefs.getBool('enter_to_send') ?? false;
      _fontSize = prefs.getDouble('font_size') ?? 14.0;
      _mediaAutoDownload = prefs.getBool('media_auto_download') ?? true;
      _readReceipts = prefs.getBool('read_receipts') ?? true;
      _onlineStatus = prefs.getBool('online_status') ?? true;
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: _buildPage(),
    );
  }

  Widget _buildPage() {
    switch (widget.page) {
      case 0: return _buildProfilePage();
      case 1: return _buildNotificationsPage();
      case 2: return _buildChatsPage();
      case 3: return _buildCallsPage();
      case 4: return _buildAccountPage();
      case 5: return _buildAboutPage();
      default: return _buildProfilePage();
    }
  }

  Widget _pageScroll(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: AppSizes.headerHeight,
          color: AppColors.panel,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: AppText.title),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textGrey),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body),
                  if (subtitle != null)
                    Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _section(String label, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Text(label.toUpperCase(),
              style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ),
        ...tiles.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: t,
            )),
      ],
    );
  }

  Widget _buildProfilePage() {
    final me = widget.me;
    return _pageScroll('Profile', [
      Center(
        child: Column(
          children: [
            UserAvatar(
                imageUrl: me?.avatarUrl,
                name: me?.name ?? 'Me',
                size: 72),
            const SizedBox(height: 12),
            Text(me?.name ?? '', style: AppText.title),
            Text(me?.email ?? '', style: AppText.bodyGrey),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _section('Personal Info', [
        _settingsTile(
          title: 'Name',
          subtitle: me?.name ?? '',
          icon: Icons.person_outline,
          trailing: const Icon(Icons.edit_outlined,
              size: 16, color: AppColors.textHint),
        ),
        _settingsTile(
          title: 'Bio',
          subtitle: me?.bio.isNotEmpty == true ? me!.bio : 'No bio set',
          icon: Icons.info_outline,
          trailing: const Icon(Icons.edit_outlined,
              size: 16, color: AppColors.textHint),
        ),
        _settingsTile(
          title: 'Phone',
          subtitle: me?.phoneInfo.isNotEmpty == true
              ? me!.phoneInfo
              : 'Not set',
          icon: Icons.phone_outlined,
          trailing: const Icon(Icons.edit_outlined,
              size: 16, color: AppColors.textHint),
        ),
      ]),
    ]);
  }

  Widget _buildNotificationsPage() {
    return _pageScroll('Notifications', [
      _section('Messages', [
        _settingsTile(
          title: 'Message Notifications',
          subtitle: 'Show alerts for new messages',
          icon: Icons.chat_bubble_outline,
          trailing: Switch(
            value: _msgNotif,
            onChanged: (v) {
              setState(() => _msgNotif = v);
              _savePref('notif_messages', v);
            },
          ),
        ),
        _settingsTile(
          title: 'Group Notifications',
          subtitle: 'Show alerts for group messages',
          icon: Icons.group_outlined,
          trailing: Switch(
            value: _groupNotif,
            onChanged: (v) {
              setState(() => _groupNotif = v);
              _savePref('notif_groups', v);
            },
          ),
        ),
      ]),
      _section('Calls', [
        _settingsTile(
          title: 'Call Notifications',
          subtitle: 'Show alerts for incoming calls',
          icon: Icons.call_outlined,
          trailing: Switch(
            value: _callNotif,
            onChanged: (v) {
              setState(() => _callNotif = v);
              _savePref('notif_calls', v);
            },
          ),
        ),
      ]),
      _section('Sound & Vibration', [
        _settingsTile(
          title: 'Sound',
          icon: Icons.volume_up_outlined,
          trailing: Switch(
            value: _soundEnabled,
            onChanged: (v) {
              setState(() => _soundEnabled = v);
              _savePref('notif_sound', v);
            },
          ),
        ),
        _settingsTile(
          title: 'Vibration',
          icon: Icons.vibration,
          trailing: Switch(
            value: _vibration,
            onChanged: (v) {
              setState(() => _vibration = v);
              _savePref('notif_vibration', v);
            },
          ),
        ),
      ]),
    ]);
  }

  Widget _buildChatsPage() {
    return _pageScroll('Chats', [
      _section('Input', [
        _settingsTile(
          title: 'Enter to Send',
          subtitle: 'Press Enter key to send messages',
          icon: Icons.keyboard_return,
          trailing: Switch(
            value: _enterToSend,
            onChanged: (v) {
              setState(() => _enterToSend = v);
              _savePref('enter_to_send', v);
            },
          ),
        ),
      ]),
      _section('Appearance', [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 18,
                      color: AppColors.textGrey),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Font Size')),
                  Text('${_fontSize.round()}px',
                      style: AppText.caption),
                ],
              ),
              Slider(
                value: _fontSize,
                min: 11,
                max: 20,
                divisions: 9,
                onChanged: (v) {
                  setState(() => _fontSize = v);
                  _savePref('font_size', v);
                },
              ),
            ],
          ),
        ),
      ]),
      _section('Media', [
        _settingsTile(
          title: 'Auto-download Media',
          subtitle: 'Automatically download images and files',
          icon: Icons.download_outlined,
          trailing: Switch(
            value: _mediaAutoDownload,
            onChanged: (v) {
              setState(() => _mediaAutoDownload = v);
              _savePref('media_auto_download', v);
            },
          ),
        ),
      ]),
    ]);
  }

  Widget _buildCallsPage() {
    return _pageScroll('Calls', [
      _section('Call Settings', [
        _settingsTile(
          title: 'Default Microphone',
          subtitle: 'System default',
          icon: Icons.mic_outlined,
          trailing: const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textHint),
        ),
        _settingsTile(
          title: 'Default Speaker',
          subtitle: 'System default',
          icon: Icons.volume_up_outlined,
          trailing: const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textHint),
        ),
        _settingsTile(
          title: 'Default Camera',
          subtitle: 'System default',
          icon: Icons.videocam_outlined,
          trailing: const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textHint),
        ),
      ]),
    ]);
  }

  Widget _buildAccountPage() {
    return _pageScroll('Account & Privacy', [
      _section('Privacy', [
        _settingsTile(
          title: 'Read Receipts',
          subtitle: 'Let others know when you\'ve read their messages',
          icon: Icons.done_all,
          trailing: Switch(
            value: _readReceipts,
            onChanged: (v) {
              setState(() => _readReceipts = v);
              _savePref('read_receipts', v);
            },
          ),
        ),
        _settingsTile(
          title: 'Show Online Status',
          subtitle: 'Let others see when you\'re active',
          icon: Icons.circle,
          trailing: Switch(
            value: _onlineStatus,
            onChanged: (v) {
              setState(() => _onlineStatus = v);
              _savePref('online_status', v);
            },
          ),
        ),
      ]),
      _section('Account', [
        _settingsTile(
          title: 'Blocked Contacts',
          icon: Icons.block,
          trailing: const Icon(Icons.chevron_right,
              size: 18, color: AppColors.textHint),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton(
          onPressed: widget.onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          child: const Text('Sign Out'),
        ),
      ),
    ]);
  }

  Widget _buildAboutPage() {
    return _pageScroll('About', [
      _section('App Info', [
        _settingsTile(
            title: 'Version', subtitle: '2.0.0', icon: Icons.info_outline),
        _settingsTile(
            title: 'Build',
            subtitle: 'Windows Desktop',
            icon: Icons.computer_outlined),
      ]),
      _section('Support', [
        _settingsTile(
          title: 'Terms of Service',
          icon: Icons.article_outlined,
          trailing: const Icon(Icons.open_in_new,
              size: 16, color: AppColors.textHint),
        ),
        _settingsTile(
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          trailing: const Icon(Icons.open_in_new,
              size: 16, color: AppColors.textHint),
        ),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────
// INLINE CHAT PANEL (Panel C — tab 0, chat selected)
// ─────────────────────────────────────────────────────
class _InlineChatPanel extends ConsumerStatefulWidget {
  final ChatModel chat;
  final VoidCallback onBack;

  const _InlineChatPanel({
    super.key,
    required this.chat,
    required this.onBack,
  });

  @override
  ConsumerState<_InlineChatPanel> createState() => _InlineChatPanelState();
}

class _InlineChatPanelState extends ConsumerState<_InlineChatPanel> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  MessageModel? _replyTo;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    // Mark messages as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAllRead(widget.chat.id);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _chatId => widget.chat.id;
  UserModel? get _other => widget.chat.otherUser;
  String get _otherId {
    final uid = ref.read(currentUserIdProvider);
    return widget.chat.getOtherUserId(uid);
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    try {
      await ref.read(chatServiceProvider).sendTextMessage(
            chatId: _chatId,
            receiverId: _otherId,
            text: text,
            replyTo: _replyTo?.id,
            replyPreview: _replyTo?.text ?? '',
          );
      setState(() => _replyTo = null);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final otherStream = ref.watch(userStreamProvider(_otherId));
    final other = otherStream.valueOrNull ?? _other;

    return Column(
      children: [
        // ── Header ──────────────────────────────────
        Container(
          height: AppSizes.headerHeight,
          color: AppColors.panel,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: other?.avatarUrl,
                name: other?.name ?? '?',
                size: 38,
                showOnline: true,
                isOnline: other?.isOnline ?? false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other?.name ?? 'Chat',
                        style: AppText.name),
                    Text(
                      (other?.isOnline ?? false)
                          ? '● online'
                          : 'last seen recently',
                      style: AppText.caption.copyWith(
                        color: (other?.isOnline ?? false)
                            ? AppColors.online
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Voice Call',
                onPressed: () => _startCall(false),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Video Call',
                onPressed: () => _startCall(true),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
                onPressed: () {},
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Messages ─────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ref.read(chatServiceProvider).streamMessages(_chatId),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return ErrorState(error: snap.error);
              }
              if (!snap.hasData) return const LoadingWidget();
              final rows = snap.data!;
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No messages yet',
                  subtitle: 'Send a message to start the conversation',
                );
              }
              final msgs = rows
                  .map((r) => MessageModel.fromMap(r))
                  .where((m) => !m.isDeletedForUser(uid))
                  .toList();

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final msg = msgs[i];
                  final isSent = msg.senderId == uid;
                  final showDate = i == 0 ||
                      !_sameDay(msgs[i - 1].createdAt, msg.createdAt);

                  return Column(
                    children: [
                      if (showDate) _DateChip(dt: msg.createdAt),
                      _MessageBubbleTile(
                        msg: msg,
                        isSent: isSent,
                        onReply: () =>
                            setState(() => _replyTo = msg),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // ── Reply preview ─────────────────────────────
        if (_replyTo != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.accentLight,
            child: Row(
              children: [
                Container(
                    width: 3,
                    height: 36,
                    color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying to message',
                          style: AppText.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                      Text(
                        _replyTo!.text.isNotEmpty
                            ? _replyTo!.text
                            : '(Media)',
                        style: AppText.bodyGrey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),

        // ── Input bar ─────────────────────────────────
        const Divider(height: 1),
        Container(
          constraints:
              const BoxConstraints(minHeight: AppSizes.inputBarHeight),
          color: AppColors.panel,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                tooltip: 'Emoji',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.attach_file_outlined),
                tooltip: 'Attach',
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  maxLines: 6,
                  minLines: 1,
                  style: AppText.body,
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: AppText.hint,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.bg,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Send / Mic toggle
              _textCtrl.text.trim().isNotEmpty
                  ? IconButton(
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: AppColors.white, size: 18),
                      ),
                      onPressed: _sending ? null : _sendMessage,
                    )
                  : IconButton(
                      icon: const Icon(Icons.mic_outlined),
                      tooltip: 'Voice note',
                      onPressed: () {},
                    ),
            ],
          ),
        ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _startCall(bool isVideo) async {
    final webrtcService = ref.read(webrtcServiceProvider);
    try {
      final callId = await webrtcService.initiateCall(
        _otherId,
        isVideo: isVideo,
      );
      if (!mounted) return;
      if (isVideo) {
        context.push('/video-call/$callId',
            extra: {'isCaller': true, 'user': _other, 'sdpOffer': ''});
      } else {
        context.push('/voice-call/$callId',
            extra: {'isCaller': true, 'user': _other, 'sdpOffer': ''});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start call: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────
// MESSAGE BUBBLE TILE  (inline for home chat panel)
// ─────────────────────────────────────────────────────
class _MessageBubbleTile extends StatelessWidget {
  final MessageModel msg;
  final bool isSent;
  final VoidCallback onReply;

  const _MessageBubbleTile({
    required this.msg,
    required this.isSent,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          child: GestureDetector(
            onSecondaryTap: () =>
                _showContextMenu(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: isSent ? AppDeco.sentBubble : AppDeco.recvBubble,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview
                  if (msg.replyPreview.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSent
                            ? Colors.black.withOpacity(0.06)
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(
                              color: AppColors.accent, width: 3),
                        ),
                      ),
                      child: Text(
                        msg.replyPreview,
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // Forwarded label
                  if (msg.isForwarded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forward,
                              size: 12, color: AppColors.textHint),
                          const SizedBox(width: 2),
                          Text('Forwarded',
                              style: AppText.caption.copyWith(
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),

                  // Message text
                  if (msg.text.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(msg.text, style: AppText.body),
                    ),

                  // Timestamp + ticks
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(msg.createdAt),
                        style: AppText.timestamp,
                      ),
                      if (isSent) ...[
                        const SizedBox(width: 4),
                        _TickWidget(status: msg.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        isSent
            ? MediaQuery.of(context).size.width - 200
            : 100,
        100, 0, 0,
      ),
      items: [
        PopupMenuItem(
          onTap: onReply,
          child: const Row(children: [
            Icon(Icons.reply, size: 16),
            SizedBox(width: 8),
            Text('Reply'),
          ]),
        ),
      ],
    );
  }
}

class _TickWidget extends StatelessWidget {
  final MessageStatus status;
  const _TickWidget({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.textHint),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: AppColors.textHint);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 13,
            color: AppColors.textHint);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 13,
            color: AppColors.accent);
    }
  }
}

class _DateChip extends StatelessWidget {
  final DateTime dt;
  const _DateChip({required this.dt});

  String get _label {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_label, style: AppText.caption),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ADD CONTACT DIALOG
// ─────────────────────────────────────────────────────
class _AddContactDialog extends ConsumerStatefulWidget {
  final ValueChanged<ChatModel> onChatOpened;
  const _AddContactDialog({required this.onChatOpened});

  @override
  ConsumerState<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends ConsumerState<_AddContactDialog> {
  int _searchBy = 0; // 0=Email, 1=Phone
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  bool _saving = false;
  UserModel? _found;
  String? _notFoundMsg;
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _found = null;
      _notFoundMsg = null;
    });
    try {
      final uid = ref.read(currentUserIdProvider);
      final db = Supabase.instance.client;
      Map<String, dynamic>? data;

      if (_searchBy == 0) {
        data = await db
            .from('users')
            .select()
            .eq('email', q)
            .eq('is_private', false)
            .maybeSingle();
      } else {
        data = await db
            .from('users')
            .select()
            .eq('phone_info', q)
            .eq('is_private', false)
            .maybeSingle();
      }

      if (!mounted) return;
      if (data == null) {
        setState(() => _notFoundMsg = 'No user found with that ${_searchBy == 0 ? 'email' : 'phone'}.');
      } else if (data['id'] == uid) {
        setState(() => _notFoundMsg = 'That\'s your own account.');
      } else {
        final user = UserModel.fromMap(data);
        setState(() {
          _found = user;
          _nameCtrl.text = user.name;
        });
      }
    } catch (e) {
      setState(() => _notFoundMsg = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveAndOpen() async {
    if (_found == null) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final db = Supabase.instance.client;

      // Save to contacts
      await db.from('saved_contacts').upsert({
        'user_id': uid,
        'contact_id': _found!.id,
        'nickname': _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : _found!.name,
      }, onConflict: 'user_id,contact_id');

      // Get or create chat
      final chatId =
          await ref.read(chatServiceProvider).getOrCreateChat(_found!.id);

      // Build a local ChatModel to open
      final chat = ChatModel(
        id: chatId,
        user1Id: uid,
        user2Id: _found!.id,
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        otherUser: _found!.copyWith(name: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : _found!.name),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChatOpened(chat);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text('New Chat', style: AppText.title),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab row
                  Row(
                    children: [
                      _TabChip(
                          label: 'By Email',
                          selected: _searchBy == 0,
                          onTap: () => setState(() {
                                _searchBy = 0;
                                _found = null;
                                _notFoundMsg = null;
                              })),
                      const SizedBox(width: 8),
                      _TabChip(
                          label: 'By Phone',
                          selected: _searchBy == 1,
                          onTap: () => setState(() {
                                _searchBy = 1;
                                _found = null;
                                _notFoundMsg = null;
                              })),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: AppText.body,
                          keyboardType: _searchBy == 0
                              ? TextInputType.emailAddress
                              : TextInputType.phone,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            hintText: _searchBy == 0
                                ? 'Enter email address'
                                : 'Enter phone number',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: _searching ? null : _search,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(70, 38)),
                          child: _searching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white))
                              : const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Result
                  if (_notFoundMsg != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_off,
                              size: 18, color: AppColors.textHint),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_notFoundMsg!,
                                  style: AppText.bodyGrey)),
                        ],
                      ),
                    ),

                  if (_found != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                              imageUrl: _found!.avatarUrl,
                              name: _found!.name,
                              size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_found!.name, style: AppText.name),
                                Text(_found!.email,
                                    style: AppText.bodyGrey),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle,
                              color: AppColors.accent, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Save as:', style: AppText.bodyGrey),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Display name',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveAndOpen,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white))
                            : const Text('Save & Open Chat'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            color: selected ? AppColors.white : AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// INCOMING CALL OVERLAY  (top-right popup)
// ─────────────────────────────────────────────────────
class _IncomingCallOverlay extends ConsumerWidget {
  final CallModel call;
  const _IncomingCallOverlay({required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.call_outlined,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 6),
                  Text('Incoming Call', style: AppText.name),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<UserModel?>(
                future: ref.read(chatServiceProvider).getUserById(call.callerId),
                builder: (_, snap) {
                  final caller = snap.data;
                  return Row(
                    children: [
                      UserAvatar(
                          imageUrl: caller?.avatarUrl,
                          name: caller?.name ?? '?',
                          size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(caller?.name ?? 'Unknown',
                                style: AppText.name),
                            Text(
                              call.type == CallType.video
                                  ? 'Video Call'
                                  : 'Voice Call',
                              style: AppText.bodyGrey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(webrtcServiceProvider).rejectCall(call.id);
                        },
                        icon: const Icon(Icons.call_end, size: 16),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          textStyle: const TextStyle(
                              fontFamily: 'Segoe UI', fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (call.type == CallType.video) {
                            context.push('/video-call/${call.id}',
                                extra: {
                                  'isCaller': false,
                                  'user': null
                                });
                          } else {
                            context.push('/voice-call/${call.id}',
                                extra: {
                                  'isCaller': false,
                                  'user': null
                                });
                          }
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                              fontFamily: 'Segoe UI', fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

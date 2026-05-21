import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/add_contact_sheet.dart';
import '../../widgets/common/user_avatar.dart';
import 'home_tabs/chats_tab.dart';
import 'home_tabs/status_tab.dart';
import 'home_tabs/calls_tab.dart';
import '../chat/private_chat_screen.dart';
import '../chat/group_chat_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  final _searchCtrl = TextEditingController();
  // For 2-panel desktop layout
  _ThreadItem? _activeThread;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (_tabController.index != _currentIndex) {
          ref.read(searchQueryProvider.notifier).state = '';
          _searchCtrl.clear();
          setState(() => _currentIndex = _tabController.index);
        }
      });
    _setOnline();
    _listenIncomingCalls();
  }

  Future<void> _setOnline() async {
    await ref.read(authServiceProvider).updateOnlineStatus(true);
  }

  void _listenIncomingCalls() {
    ref.listenManual(incomingCallProvider, (_, next) {
      final call = next.value;
      if (call != null && mounted) {
        context.push('/incoming-call', extra: call);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isDesktop => MediaQuery.of(context).size.width > 900;

  void _openThread(_ThreadItem item) {
    if (_isDesktop) {
      setState(() => _activeThread = item);
      return;
    }

    if (item.kind == _ThreadKind.group) {
      context.push(
        '/group-chat/${item.group!.id}',
        extra: {'group': item.group},
      );
      return;
    }

    context.push(
      '/chat/${item.chat!.id}',
      extra: {'user': item.chat!.otherUser},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  // ─── DESKTOP 2-panel layout ────────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      body: Row(children: [
        // Navigation Rail
        _buildNavigationRail(),
        // Left panel — fixed 360px sidebar
        SizedBox(
          width: 360,
          child: _buildLeftPanel(),
        ),
        // Right panel — fills remaining width
        Expanded(
          child: _buildRightPanel(),
        ),
      ]),
    );
  }

  Widget _buildRightPanel() {
    switch (_currentIndex) {
      case 1: return _buildCallsRightPanel();
      case 2: return _buildStatusRightPanel();
      case 0:
      default:
        if (_activeThread == null) return _buildEmptyPanel();

        if (_activeThread!.kind == _ThreadKind.group) {
          final g = _activeThread!.group!;
          return GroupChatScreen(
            key: ValueKey('group-${g.id}'),
            groupId: g.id,
            group: g,
          );
        }

        final c = _activeThread!.chat!;
        return PrivateChatScreen(
          key: ValueKey('chat-${c.id}'),
          chatId: c.id,
          otherUser: c.otherUser,
        );
    }
  }

  Widget _buildCallsRightPanel() {
    return Container(
      color: AppColors.chatBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _callActionBtn(Icons.video_call, 'Start call', onTap: () {
                  showDialog(context: context, builder: (_) => const AddContactSheet());
                }),
                const SizedBox(width: 40),
                _callActionBtn(Icons.link, 'New call link', onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!')));
                }),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _callActionBtn(Icons.dialpad, 'Call a number', onTap: () {
                  showDialog(context: context, builder: (_) => const AddContactSheet());
                }),
                const SizedBox(width: 40),
                _callActionBtn(Icons.calendar_month, 'Schedule call', onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!')));
                }),
              ],
            ),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
                SizedBox(width: 6),
                Text('Your personal calls are end-to-end encrypted', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _callActionBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
              child: Icon(icon, size: 30, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRightPanel() {
    return Container(
      color: AppColors.chatBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.donut_large, size: 80, color: AppColors.textHint),
            const SizedBox(height: 24),
            const Text('Share status updates', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
            const SizedBox(height: 12),
            const Text('Share photos, videos and text that disappear after 24 hours.', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Container(
      width: 60,
      color: AppColors.bgSecondary,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _railIcon(Icons.chat_outlined, 0),
          const SizedBox(height: 12),
          _railIcon(Icons.call_outlined, 1),
          const SizedBox(height: 12),
          _railIcon(Icons.donut_large_outlined, 2), // Status
          const Spacer(),
          _railIcon(Icons.settings_outlined, 3),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: UserAvatar(
              url: user?.avatarUrl,
              name: user?.name ?? 'Me',
              isOnline: false,
              radius: 14,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _railIcon(IconData icon, int index) {
    final isActive = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, color: isActive ? AppColors.textPrimary : AppColors.textHint, size: 24),
      onPressed: () {
        if (index < 3) {
           _tabController.animateTo(index);
        } else if (index == 3) {
           context.push('/settings');
        }
      },
    );
  }

  Widget _buildEmptyPanel() {
    return Container(
      color: AppColors.chatBg,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/images/wa_desktop_bg.png',
            width: 280,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.message_outlined, size: 120, color: AppColors.textHint)),
        const SizedBox(height: 24),
        const Text('XmeChat for Windows',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w300, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        const Text(
          'Send and receive messages without keeping your\nphone online. Use XmeChat on up to 4 linked devices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textHint, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 60),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
          SizedBox(width: 6),
          Text('End-to-end encrypted',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ]),
      ]),
    );
  }

  // ─── Left sidebar panel ────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    return Container(
      color: Colors.white,
      child: Column(children: [
        _buildDynamicHeader(),
        _buildDynamicSearchBar(),
        if (_currentIndex == 0) _buildChatFilters(),
        const Divider(height: 1),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DesktopChatsTab(
                onThreadOpen: _openThread,
                activeFilter: _activeFilter,
                searchQuery: ref.watch(searchQueryProvider),
              ),
              const CallsTab(),
              const StatusTab(),
            ],
          ),
        ),
      ]),
    );
  }

  String _activeFilter = 'All';

  Widget _buildChatFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('All'),
          _filterChip('Unread'),
          _filterChip('Favourites'),
          _filterChip('Groups'),
          _filterChip('+'),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    bool isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sentBubble : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _buildDynamicHeader() {
    String title = '';
    List<Widget> actions = [];
    switch (_currentIndex) {
      case 1:
        title = 'Calls';
        actions = [IconButton(icon: const Icon(Icons.add_call, size: 22, color: AppColors.textPrimary), onPressed: () {})];
        break;
      case 2:
        title = 'Status';
        actions = [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 22, color: AppColors.textPrimary),
            onPressed: () => context.push('/create-status'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22, color: AppColors.textPrimary),
            onPressed: () {
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final RenderBox button = context.findRenderObject() as RenderBox;
              final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlay),
                  button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                ),
                Offset.zero & overlay.size,
              );
              showMenu(
                context: context,
                position: position,
                items: [
                  const PopupMenuItem(
                    value: 'create',
                    child: Text('Create status update'),
                  ),
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View my status'),
                  ),
                ],
              ).then((value) {
                if (value == 'create') {
                  router.push('/create-status');
                } else if (value == 'view') {
                  final myId = ref.read(authServiceProvider).currentUserId;
                  final myStatuses = ref.read(myStatusesProvider).valueOrNull ?? [];
                  if (myStatuses.isNotEmpty) {
                    router.push('/status/$myId', extra: {'statuses': myStatuses});
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('No status updates yet.')),
                    );
                  }
                }
              });
            },
          ),
        ];
        break;
      case 0:
      default:
        title = 'Chats';
        actions = [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22, color: AppColors.textHint),
            tooltip: 'New chat',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddContactSheet(),
            ),
          ),
          IconButton(icon: const Icon(Icons.more_vert, size: 22, color: AppColors.textHint), onPressed: _showSidebarMenu),
        ];
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildDynamicSearchBar() {
    if (_currentIndex == 2) return const SizedBox.shrink(); 
    String hint = 'Search or start a new chat';
    if (_currentIndex == 1) hint = 'Search name or number';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (val) {
            ref.read(searchQueryProvider.notifier).state = val;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 18),
            filled: true,
            fillColor: AppColors.bgSecondary,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }



  void _showSidebarMenu() {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(300, 60, 0, 0),
      items: const [
        PopupMenuItem(value: 'new_group', child: Text('New group')),
        PopupMenuItem(value: 'contacts', child: Text('Contacts')),
        PopupMenuItem(value: 'settings', child: Text('Settings')),
      ],
    ).then((v) {
      if (!mounted) return;
      if (v == 'new_group') context.push('/create-group');
      if (v == 'contacts') context.push('/contacts');
      if (v == 'settings') context.push('/settings');
    });
  }



  // ─── MOBILE single-panel layout ────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('XmeChat',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textHint),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddContactSheet(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textHint),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textHint),
            onSelected: (v) {
              if (v == 'new_group') context.push('/create-group');
              if (v == 'contacts') context.push('/contacts');
              if (v == 'settings') context.push('/settings');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new_group', child: Text('New group')),
              PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ChatsTab(), StatusTab(), CallsTab()],
      ),
    );
  }
}

// ─── Desktop Chats Tab with open callback ──────────────────────────────────
class _DesktopChatsTab extends ConsumerWidget {
  final void Function(_ThreadItem item) onThreadOpen;
  final String activeFilter;
  final String searchQuery;
  const _DesktopChatsTab({required this.onThreadOpen, required this.activeFilter, this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chats) {
        final groups = groupsAsync.valueOrNull ?? const <GroupModel>[];
        final query = searchQuery.trim().toLowerCase();

        var filteredChats = chats;
        var filteredGroups = groups;
        if (query.isNotEmpty) {
          filteredChats = chats.where((c) => c.otherUser?.name.toLowerCase().contains(query) ?? false).toList();
          filteredGroups = groups.where((g) => g.name.toLowerCase().contains(query)).toList();
        }

        final items = <_ThreadItem>[
          ...filteredChats.map((c) => _ThreadItem.chat(c)),
          ...filteredGroups.map((g) => _ThreadItem.group(g)),
        ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

        List<_ThreadItem> filtered = items;
        if (activeFilter == 'Unread') {
          filtered = items.where((i) {
            if (i.kind == _ThreadKind.chat) return (i.chat!.unreadCount > 0);
            if (i.kind == _ThreadKind.group) return (i.group!.unreadCount > 0);
            return false;
          }).toList();
        } else if (activeFilter == 'Favourites') {
          filtered = items;
        } else if (activeFilter == 'Groups') {
          filtered = items.where((i) => i.kind == _ThreadKind.group).toList();
        }

        if (query.isNotEmpty) {
          final searchResults = ref.watch(searchResultsProvider).valueOrNull ?? [];
          final existingUserIds = chats.map((c) => c.otherUser?.id).toSet();
          final newContacts = searchResults.where((u) => !existingUserIds.contains(u.id)).toList();

          if (filtered.isEmpty && newContacts.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, size: 60, color: AppColors.textHint),
                SizedBox(height: 12),
                Text('No matches found', style: TextStyle(color: AppColors.textSecondary)),
              ]),
            );
          }

          return ListView(
            children: [
              if (filtered.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('CHATS & GROUPS', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ...filtered.map((item) {
                  if (item.kind == _ThreadKind.group) {
                    return _DesktopGroupTile(
                      group: item.group!,
                      onTap: () => onThreadOpen(item),
                    );
                  }
                  return _DesktopChatTile(
                    chat: item.chat!,
                    other: item.chat!.otherUser,
                    onTap: () => onThreadOpen(item),
                  );
                }),
              ],
              if (newContacts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('START A NEW CHAT', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                ...newContacts.map((user) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: UserAvatar(url: user.avatarUrl, name: user.name, radius: 26, isOnline: user.isOnline),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  subtitle: Text(user.bio.isNotEmpty ? user.bio : 'Hey there! I am using XmeChat.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    final chatSvc = ref.read(chatServiceProvider);
                    final chatId = await chatSvc.getOrCreateChat(user.id);
                    if (!context.mounted) return;
                    onThreadOpen(_ThreadItem.chat(ChatModel(
                      id: chatId,
                      user1Id: ref.read(authServiceProvider).currentUserId,
                      user2Id: user.id,
                      lastMessageAt: DateTime.now(),
                      createdAt: DateTime.now(),
                    )..otherUser = user));
                  },
                )),
              ],
            ],
          );
        }

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No chats here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textHint)));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 0.5, indent: 72, color: AppColors.divider),
          itemBuilder: (ctx, i) {
            final item = filtered[i];
            if (item.kind == _ThreadKind.group) {
              return _DesktopGroupTile(
                group: item.group!,
                onTap: () => onThreadOpen(item),
              );
            }
            return _DesktopChatTile(
              chat: item.chat!,
              other: item.chat!.otherUser,
              onTap: () => onThreadOpen(item),
            );
          },
        );
      },
    );
  }
}

class _DesktopChatTile extends StatefulWidget {
  final ChatModel chat;
  final UserModel? other;
  final VoidCallback onTap;
  const _DesktopChatTile(
      {required this.chat, this.other, required this.onTap});
  @override
  State<_DesktopChatTile> createState() => _DesktopChatTileState();
}

class _DesktopChatTileState extends State<_DesktopChatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? AppColors.bgSecondary : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: UserAvatar(
              url: widget.other?.avatarUrl,
              name: widget.other?.name ?? '?',
              isOnline: widget.other?.isOnline ?? false,
              radius: 24),
          title: Text(
            widget.other?.name ?? 'Unknown',
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: AppColors.textPrimary),
          ),
          subtitle: Text(
            widget.chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class _DesktopGroupTile extends StatefulWidget {
  final GroupModel group;
  final VoidCallback onTap;
  const _DesktopGroupTile({required this.group, required this.onTap});
  @override
  State<_DesktopGroupTile> createState() => _DesktopGroupTileState();
}

class _DesktopGroupTileState extends State<_DesktopGroupTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? AppColors.bgSecondary : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.accentGreen,
            backgroundImage: widget.group.iconUrl.isNotEmpty
                ? NetworkImage(widget.group.iconUrl)
                : null,
            child: widget.group.iconUrl.isEmpty
                ? const Icon(Icons.group, color: Colors.white, size: 18)
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.group, size: 14, color: AppColors.textHint),
            ],
          ),
          subtitle: Text(
            widget.group.lastMessage.isEmpty
                ? 'Tap to start chatting'
                : widget.group.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

enum _ThreadKind { chat, group }

class _ThreadItem {
  final _ThreadKind kind;
  final ChatModel? chat;
  final GroupModel? group;
  final DateTime lastAt;

  const _ThreadItem._({
    required this.kind,
    required this.chat,
    required this.group,
    required this.lastAt,
  });

  factory _ThreadItem.chat(ChatModel c) => _ThreadItem._(
        kind: _ThreadKind.chat,
        chat: c,
        group: null,
        lastAt: c.lastMessageAt,
      );

  factory _ThreadItem.group(GroupModel g) => _ThreadItem._(
        kind: _ThreadKind.group,
        chat: null,
        group: g,
        lastAt: g.lastMessageAt,
      );
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import 'home_tabs/chats_tab.dart';
import 'home_tabs/status_tab.dart';
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
  _ThreadItem? _activeThread;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
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

  // ── Glass card builders ───────────────────────────────────────

  Widget _glassCard({
    required Widget child,
    double borderRadius = 16,
    double blur = 30,
    Color bg = AppColors.glassBg,
    EdgeInsetsGeometry? padding,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: AppColors.glassBorder),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Desktop Layout ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(children: [
        _buildNavDrawer(),
        Expanded(child: _buildDesktopMain()),
      ]),
    );
  }

  // ── Desktop Navigation Drawer (288px) ─────────────────────────

  Widget _buildNavDrawer() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final navItems = [
      _NavItem(Icons.chat_bubble_outline, 'Messages', 0),
      _NavItem(Icons.auto_awesome, 'Status', 1),
      _NavItem(Icons.contacts_outlined, 'People', 2),
      _NavItem(Icons.settings_outlined, 'Settings', 3),
    ];

    return SizedBox(
      width: 288,
      child: _glassCard(
        borderRadius: 0,
        blur: 40,
        bg: AppColors.surface.withValues(alpha: 0.85),
        border: const Border(
          right: BorderSide(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // App Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, AppColors.primaryFixed],
                      ),
                    ),
                    child: const Icon(Icons.nightlight_round,
                        size: 18, color: AppColors.onSecondary),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Deep Space',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // User Avatar + Name
            GestureDetector(
              onTap: () => context.push('/settings'),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      url: user?.avatarUrl,
                      name: user?.name ?? 'Me',
                      isOnline: true,
                      radius: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Online',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Nav Items
            ...navItems.asMap().entries.map((entry) {
              final i = entry.value;
              final isActive = _currentIndex == i.index;
              final isSettings = i.index == 3;
              final isPeople = i.index == 2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (isSettings) {
                        context.push('/settings');
                      } else if (isPeople) {
                        context.push('/contacts');
                      } else {
                        _tabController.animateTo(i.index);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            i.icon,
                            size: 22,
                            color: isActive
                                ? AppColors.primaryFixed
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            i.label,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.primaryFixed
                                  : AppColors.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          if (isActive)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            // Bottom section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.headphones_outlined,
                      size: 18, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Support',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Main Content ──────────────────────────────────────

  Widget _buildDesktopMain() {
    if (_activeThread != null) {
      return _buildRightPanel();
    }

    return Column(
      children: [
        _buildStoriesRail(),
        Expanded(child: _buildConversationList()),
      ],
    );
  }

  // ── Stories Rail ("Active Frequencies") ───────────────────────

  Widget _buildStoriesRail() {
    final statusesAsync = ref.watch(statusesProvider);
    final myStatusesAsync = ref.watch(myStatusesProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final myId = ref.read(authServiceProvider).currentUserId;

    final statuses = statusesAsync.valueOrNull ?? [];
    final myStatuses = myStatusesAsync.valueOrNull ?? [];

    final Map<String, List<StatusModel>> grouped = {};
    for (final s in statuses) {
      if (s.userId == myId) continue;
      grouped[s.userId] = (grouped[s.userId] ?? [])..add(s);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fiber_manual_record,
                  size: 8, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'ACTIVE FREQUENCIES',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Add Story
                GestureDetector(
                  onTap: () => context.push('/create-status'),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.glassBorder,
                              width: 2,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.add,
                                size: 28, color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add Story',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // My Status
                GestureDetector(
                  onTap: () {
                    if (myStatuses.isEmpty) {
                      context.push('/create-status');
                    } else {
                      context.push(
                        '/status/$myId',
                        extra: {'statuses': myStatuses},
                      );
                    }
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                AppColors.secondary,
                                AppColors.primaryFixed,
                                AppColors.secondary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                            ),
                            child: UserAvatar(
                              url: me?.avatarUrl,
                              name: me?.name ?? 'Me',
                              radius: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Other users' statuses
                ...grouped.entries.map((entry) {
                  final userStatuses = entry.value;
                  final user = userStatuses.first.user;
                  final allViewed = userStatuses.every((s) => s.viewedByMe);
                  return GestureDetector(
                    onTap: () => context.push(
                      '/status/${entry.key}',
                      extra: {'statuses': userStatuses},
                    ),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: allViewed
                                  ? null
                                  : const SweepGradient(
                                      colors: [
                                        AppColors.secondary,
                                        AppColors.primaryFixed,
                                        AppColors.secondary,
                                      ],
                                    ),
                              boxShadow: allViewed
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 10,
                                      ),
                                    ],
                            ),
                            padding: allViewed ? null : const EdgeInsets.all(2),
                            child: Opacity(
                              opacity: allViewed ? 0.5 : 1.0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                ),
                                child: UserAvatar(
                                  url: user?.avatarUrl,
                                  name: user?.name ?? '?',
                                  radius: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.name ?? 'Unknown',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Conversation List ─────────────────────────────────────────

  Widget _buildConversationList() {
    final chatsAsync = ref.watch(chatsStreamProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return chatsAsync.when(
      loading: () => _buildShimmerLoading(),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
      ),
      data: (chats) {
        final groups = groupsAsync.valueOrNull ?? const <GroupModel>[];
        final query = ref.watch(searchQueryProvider).trim().toLowerCase();

        var filteredChats = chats;
        var filteredGroups = groups;
        if (query.isNotEmpty) {
          filteredChats = chats
              .where((c) =>
                  c.otherUser?.name.toLowerCase().contains(query) ?? false)
              .toList();
          filteredGroups = groups
              .where((g) => g.name.toLowerCase().contains(query))
              .toList();
        }

        final items = <_ThreadItem>[
          ...filteredChats.map((c) => _ThreadItem.chat(c)),
          ...filteredGroups.map((g) => _ThreadItem.group(g)),
        ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

        if (query.isNotEmpty) {
          final searchResults =
              ref.watch(searchResultsProvider).valueOrNull ?? [];
          final existingUserIds =
              chats.map((c) => c.otherUser?.id).toSet();
          final newContacts =
              searchResults.where((u) => !existingUserIds.contains(u.id)).toList();

          if (items.isEmpty && newContacts.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off,
                    size: 60, color: AppColors.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('No matches found',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 14)),
              ]),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              if (items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Text('CHATS & GROUPS',
                      style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                ...items.map((item) {
                  if (item.kind == _ThreadKind.group) {
                    return _DesktopGroupTile(
                      group: item.group!,
                      onTap: () => _openThread(item),
                    );
                  }
                  return _DesktopChatTile(
                    chat: item.chat!,
                    other: item.chat!.otherUser,
                    onTap: () => _openThread(item),
                  );
                }),
              ],
              if (newContacts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Text('START A NEW CHAT',
                      style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                ...newContacts.map((user) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _glassCard(
                      borderRadius: 12,
                      blur: 20,
                      bg: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          url: user.avatarUrl,
                          name: user.name,
                          radius: 26,
                          isOnline: user.isOnline,
                        ),
                        title: Text(user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.onSurface)),
                        subtitle: Text(
                            user.bio.isNotEmpty
                                ? user.bio
                                : 'Hey there! I am using XmeChat.',
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          final chatSvc = ref.read(chatServiceProvider);
                          final chatId = await chatSvc.getOrCreateChat(user.id);
                          if (!context.mounted) return;
                          _openThread(_ThreadItem.chat(ChatModel(
                            id: chatId,
                            user1Id: ref.read(authServiceProvider).currentUserId,
                            user2Id: user.id,
                            lastMessageAt: DateTime.now(),
                            createdAt: DateTime.now(),
                          )..otherUser = user));
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline,
                  size: 60, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No conversations yet',
                  style: TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Start a new chat to begin',
                  style: TextStyle(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            if (item.kind == _ThreadKind.group) {
              return _DesktopGroupTile(
                group: item.group!,
                onTap: () => _openThread(item),
              );
            }
            return _DesktopChatTile(
              chat: item.chat!,
              other: item.chat!.otherUser,
              onTap: () => _openThread(item),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerLow,
      highlightColor: AppColors.surfaceContainerHigh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _glassCard(
            borderRadius: 12,
            blur: 20,
            bg: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 180,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Right Panel (Desktop Chat View) ──────────────────────────

  Widget _buildRightPanel() {
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

  Widget _buildEmptyPanel() {
    return Container(
      color: AppColors.surface,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withValues(alpha: 0.15),
                AppColors.primaryContainer.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: const Icon(Icons.message_outlined,
              size: 56, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        const Text('XmeChat for Windows',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: AppColors.onSurface)),
        const SizedBox(height: 10),
        Text(
          'Send and receive messages without keeping your\nphone online. Use XmeChat on up to 4 linked devices.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.6),
        ),
        const SizedBox(height: 60),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline,
              size: 14, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text('End-to-end encrypted',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 13)),
        ]),
      ]),
    );
  }

  // ── Mobile Layout ────────────────────────────────────────────

  Widget _buildMobileLayout() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.glassBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leadingWidth: 56,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: UserAvatar(
                    url: user?.avatarUrl,
                    name: user?.name ?? 'Me',
                    isOnline: true,
                    radius: 20,
                  ),
                ),
                title: const Text(
                  'Deep Space',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => context.push('/search'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ChatsTab(), StatusTab()],
      ),
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  Widget _buildMobileBottomNav() {
    final items = [
      (Icons.chat_bubble_outline, 'Chats'),
      (Icons.auto_awesome, 'Status'),
      (Icons.contacts_outlined, 'People'),
      (Icons.settings_outlined, 'Profile'),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.glassBg,
            border: Border(
              top: BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final (icon, label) = entry.value;
                  final isActive = _currentIndex == idx;
                  return GestureDetector(
                    onTap: () {
                      if (idx == 2) {
                        context.push('/contacts');
                      } else if (idx == 3) {
                        context.push('/settings');
                      } else {
                        _tabController.animateTo(idx);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.secondaryContainer.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 22,
                            color: isActive
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant,
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ── Desktop Chat Tile (Glass Card) ────────────────────────────

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

  Widget _glassCard({
    required Widget child,
    double borderRadius = 12,
    double blur = 20,
    Color bg = AppColors.glassBg,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.other;
    final isRead = widget.chat.unreadCount == 0;
    final hasMedia = widget.chat.lastMessageType != 'text';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: _glassCard(
            bg: _hovered
                ? AppColors.surfaceContainerHigh.withValues(alpha: 0.6)
                : AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      UserAvatar(
                        url: other?.avatarUrl,
                        name: other?.name ?? '?',
                        radius: 24,
                        borderColor: widget.chat.unreadCount > 0
                            ? AppColors.secondary
                            : null,
                      ),
                      if (other?.isOnline == true)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary,
                              border: Border.all(
                                  color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                other?.name ?? 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: widget.chat.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 15,
                                  color: !isRead
                                      ? AppColors.onSurface
                                      : AppColors.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(widget.chat.lastMessageAt,
                                  allowFromNow: true),
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Read indicator
                            if (isRead && widget.chat.lastMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.done_all,
                                    size: 14,
                                    color: AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ),
                            // Media type icon
                            if (hasMedia) ...[
                              Icon(
                                widget.chat.lastMessageType == 'image'
                                    ? Icons.photo
                                    : widget.chat.lastMessageType == 'audio'
                                        ? Icons.mic
                                        : widget.chat.lastMessageType ==
                                                'document'
                                            ? Icons.attach_file
                                            : Icons.photo,
                                size: 14,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                widget.chat.lastMessage.isEmpty
                                    ? 'Tap to start chatting'
                                    : widget.chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Unread badge
                  if (widget.chat.unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondaryContainer,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.chat.unreadCount}',
                          style: const TextStyle(
                            color: AppColors.onSecondaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Desktop Group Tile (Glass Card) ───────────────────────────

class _DesktopGroupTile extends StatefulWidget {
  final GroupModel group;
  final VoidCallback onTap;
  const _DesktopGroupTile({required this.group, required this.onTap});
  @override
  State<_DesktopGroupTile> createState() => _DesktopGroupTileState();
}

class _DesktopGroupTileState extends State<_DesktopGroupTile> {
  bool _hovered = false;

  Widget _glassCard({
    required Widget child,
    double borderRadius = 12,
    double blur = 20,
    Color bg = AppColors.glassBg,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.group.unreadCount == 0;
    final hasMedia = widget.group.lastMessageType != 'text';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: _glassCard(
            bg: _hovered
                ? AppColors.surfaceContainerHigh.withValues(alpha: 0.6)
                : AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: widget.group.iconUrl.isNotEmpty
                            ? NetworkImage(widget.group.iconUrl)
                            : null,
                        child: widget.group.iconUrl.isEmpty
                            ? const Icon(Icons.group,
                                color: AppColors.primaryFixed, size: 20)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.push_pin_outlined,
                                size: 12,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: widget.group.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 15,
                                  color: !isRead
                                      ? AppColors.onSurface
                                      : AppColors.onSurface
                                          .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(widget.group.lastMessageAt,
                                  allowFromNow: true),
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (hasMedia) ...[
                              Icon(
                                widget.group.lastMessageType == 'image'
                                    ? Icons.photo
                                    : widget.group.lastMessageType == 'audio'
                                        ? Icons.mic
                                        : widget.group.lastMessageType ==
                                                'document'
                                            ? Icons.attach_file
                                            : Icons.photo,
                                size: 14,
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                widget.group.lastMessage.isEmpty
                                    ? 'Tap to start chatting'
                                    : widget.group.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.group.unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondaryContainer,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.group.unreadCount}',
                          style: const TextStyle(
                            color: AppColors.onSecondaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting Types ──────────────────────────────────────────

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

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  _NavItem(this.icon, this.label, this.index);
}

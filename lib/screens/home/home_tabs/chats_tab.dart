import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/user_avatar.dart';

// ─────────────────────────────────────────────────────────────
// ChatsTab — Deep Space / Obsidian Flow glassmorphic design
// ─────────────────────────────────────────────────────────────

class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({super.key});

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab> {
  String _selectedFilter = 'All';
  final Set<String> _pinnedIds = {};
  final Set<String> _mutedIds = {};
  final Set<String> _archivedIds = {};

  static const _filters = ['All', 'Unread', 'Pinned', 'Groups'];

  void _togglePin(String id) {
    setState(() {
      if (_pinnedIds.contains(id)) {
        _pinnedIds.remove(id);
      } else {
        _pinnedIds.add(id);
      }
    });
  }

  void _toggleMute(String id) {
    setState(() {
      if (_mutedIds.contains(id)) {
        _mutedIds.remove(id);
      } else {
        _mutedIds.add(id);
      }
    });
  }

  void _archive(String id) {
    setState(() => _archivedIds.add(id));
  }

  void _delete(String id) {
    setState(() => _archivedIds.add(id));
  }

  // ── Lifecycle ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    final chatsAsync = ref.watch(chatsProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chats) {
        final groups = groupsAsync.valueOrNull ?? const <GroupModel>[];
        if (query.isNotEmpty) {
          return _buildSearchResults(chats, groups, query);
        }
        return _buildChatList(chats, groups);
      },
    );
  }

  // ── Search Results View ──────────────────────────────

  Widget _buildSearchResults(
      List<ChatModel> chats, List<GroupModel> groups, String query) {
    final filteredChats =
        chats.where((c) =>
                c.otherUser?.name.toLowerCase().contains(query) ?? false)
            .toList();
    final filteredGroups =
        groups.where((g) => g.name.toLowerCase().contains(query)).toList();

    final items = <_ThreadItem>[
      ...filteredChats.map((c) => _ThreadItem.chat(c)),
      ...filteredGroups.map((g) => _ThreadItem.group(g)),
    ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

    final searchResults = ref.watch(searchResultsProvider).valueOrNull ?? [];
    final existingUserIds = chats.map((c) => c.otherUser?.id).toSet();
    final newContacts =
        searchResults.where((u) => !existingUserIds.contains(u.id)).toList();

    if (items.isEmpty && newContacts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 80, color: AppColors.outline),
            SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _HeaderSection(),
        _SearchBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (items.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Text(
                    'CHATS & GROUPS',
                    style: TextStyle(
                      color: AppColors.secondary.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                ...items.map((item) {
                  if (item.kind == _ThreadKind.group) {
                    return _GroupTile(
                      group: item.group!,
                      isPinned: _pinnedIds.contains(item.id),
                      isMuted: _mutedIds.contains(item.id),
                      onPinToggle: _togglePin,
                      onMuteToggle: _toggleMute,
                      onArchive: _archive,
                      onDelete: _delete,
                    );
                  }
                  return _ChatTile(
                    chat: item.chat!,
                    isPinned: _pinnedIds.contains(item.id),
                    isMuted: _mutedIds.contains(item.id),
                    onPinToggle: _togglePin,
                    onMuteToggle: _toggleMute,
                    onArchive: _archive,
                    onDelete: _delete,
                  );
                }),
              ],
              if (newContacts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                  child: Text(
                    'START A NEW CHAT',
                    style: TextStyle(
                      color: AppColors.secondary.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                ...newContacts.map((user) => Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: _GlassCardStandard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          leading: UserAvatar(
                            url: user.avatarUrl,
                            name: user.name,
                            radius: 26,
                            isOnline: user.isOnline,
                          ),
                          title: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            user.bio.isNotEmpty
                                ? user.bio
                                : 'Hey there! I am using XmeChat.',
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            final chatSvc = ref.read(chatServiceProvider);
                            final chatId =
                                await chatSvc.getOrCreateChat(user.id);
                            if (!context.mounted) return;
                            context.push('/chat/$chatId',
                                extra: {'user': user});
                          },
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Main Chat List View ──────────────────────────────

  Widget _buildChatList(List<ChatModel> chats, List<GroupModel> groups) {
    final items = <_ThreadItem>[
      ...chats.map((c) => _ThreadItem.chat(c)),
      ...groups.map((g) => _ThreadItem.group(g)),
    ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

    final pinned = items.where((i) => _pinnedIds.contains(i.id)).toList();
    final regular = items.where((i) => !_pinnedIds.contains(i.id)).toList();

    final filtered = _applyFilter(pinned, regular);

    final hasNoContent = filtered.pinned.isEmpty && filtered.regular.isEmpty;

    return Column(
      children: [
        _HeaderSection(),
        _SearchBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _selectedFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.secondaryContainer
                          : AppColors.surfaceContainerHigh
                              .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppColors.secondaryContainer
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected
                            ? AppColors.onSecondaryContainer
                            : AppColors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (hasNoContent)
          Expanded(child: _buildEmptyState())
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(chatsProvider.future),
                  ref.refresh(groupsProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (filtered.pinned.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                      child: Text(
                        'PINNED',
                        style: TextStyle(
                          color: AppColors.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                    ...filtered.pinned.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: item.kind == _ThreadKind.group
                              ? _GroupTile(
                                  group: item.group!,
                                  isPinned: true,
                                  isMuted: _mutedIds.contains(item.id),
                                  onPinToggle: _togglePin,
                                  onMuteToggle: _toggleMute,
                                  onArchive: _archive,
                                  onDelete: _delete,
                                )
                              : _ChatTile(
                                  chat: item.chat!,
                                  isPinned: true,
                                  isMuted: _mutedIds.contains(item.id),
                                  onPinToggle: _togglePin,
                                  onMuteToggle: _toggleMute,
                                  onArchive: _archive,
                                  onDelete: _delete,
                                ),
                        )),
                  ],
                  ...filtered.regular.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: item.kind == _ThreadKind.group
                            ? _GroupTile(
                                group: item.group!,
                                isPinned: false,
                                isMuted: _mutedIds.contains(item.id),
                                onPinToggle: _togglePin,
                                onMuteToggle: _toggleMute,
                                onArchive: _archive,
                                onDelete: _delete,
                              )
                            : _ChatTile(
                                chat: item.chat!,
                                isPinned: false,
                                isMuted: _mutedIds.contains(item.id),
                                onPinToggle: _togglePin,
                                onMuteToggle: _toggleMute,
                                onArchive: _archive,
                                onDelete: _delete,
                              ),
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Filter Logic ─────────────────────────────────────

  ({List<_ThreadItem> pinned, List<_ThreadItem> regular}) _applyFilter(
    List<_ThreadItem> pinned,
    List<_ThreadItem> regular,
  ) {
    List<_ThreadItem> filtUnread(List<_ThreadItem> list) =>
        list.where((i) => i.unreadCount > 0 && !_mutedIds.contains(i.id)).toList();

    List<_ThreadItem> filtGroups(List<_ThreadItem> list) =>
        list.where((i) => i.kind == _ThreadKind.group).toList();

    List<_ThreadItem> filtDefault(List<_ThreadItem> list) =>
        list.where((i) => !_archivedIds.contains(i.id)).toList();

    switch (_selectedFilter) {
      case 'Unread':
        return (pinned: filtUnread(pinned), regular: filtUnread(regular));
      case 'Pinned':
        return (pinned: pinned, regular: <_ThreadItem>[]);
      case 'Groups':
        return (pinned: filtGroups(pinned), regular: filtGroups(regular));
      default:
        return (pinned: filtDefault(pinned), regular: filtDefault(regular));
    }
  }

  // ── Empty State ─────────────────────────────────────

  Widget _buildEmptyState() {
    String message;
    String subMessage;

    switch (_selectedFilter) {
      case 'Unread':
        message = 'No unread messages';
        subMessage = "You're all caught up";
        break;
      case 'Pinned':
        message = 'No pinned chats';
        subMessage = 'Pin important conversations';
        break;
      case 'Groups':
        message = 'No group chats';
        subMessage = 'Create or join a group';
        break;
      default:
        message = 'No messages yet';
        subMessage = 'Start a conversation';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subMessage,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Messages',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Active communications',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController.fromValue(
      TextEditingValue(text: ref.watch(searchQueryProvider)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: controller,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                filled: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GLASS CARD WRAPPERS
// ─────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final bool glow;

  const _GlassCard({
    required this.child,
    this.borderRadius = 16,
    this.blurSigma = 30,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          foregroundDecoration: glow
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.8,
                    colors: [
                      AppColors.glassInnerGlow,
                      Colors.transparent,
                    ],
                  ),
                )
              : null,
          child: child,
        ),
      ),
    );
  }
}

class _GlassCardStandard extends StatelessWidget {
  final Widget child;

  const _GlassCardStandard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GLASS CARD WRAPPER SELECTOR
// ─────────────────────────────────────────────────────────────

Widget glassCardWrapper({required bool isPinned, required Widget child}) {
  if (isPinned) {
    return _GlassCard(
      borderRadius: 16,
      blurSigma: 30,
      glow: true,
      child: child,
    );
  }
  return _GlassCardStandard(child: child);
}

// ─────────────────────────────────────────────────────────────
// CHAT TILE
// ─────────────────────────────────────────────────────────────

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final bool isPinned;
  final bool isMuted;
  final void Function(String) onPinToggle;
  final void Function(String) onMuteToggle;
  final void Function(String) onArchive;
  final void Function(String) onDelete;

  const _ChatTile({
    required this.chat,
    required this.isPinned,
    required this.isMuted,
    required this.onPinToggle,
    required this.onMuteToggle,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = chat.otherUser;

    final card = glassCardWrapper(
      isPinned: isPinned,
      child: InkWell(
        borderRadius: BorderRadius.circular(isPinned ? 16 : 12),
        onTap: () =>
            context.push('/chat/${chat.id}', extra: {'user': chat.otherUser}),
        onLongPress: () => _showChatMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                url: other?.avatarUrl,
                name: other?.name ?? '?',
                isOnline: other?.isOnline ?? false,
                radius: isPinned ? 28 : 24,
                borderColor: isPinned ? AppColors.secondary : null,
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
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 16,
                              color: isMuted
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                          ),
                        Text(
                          timeago.format(chat.lastMessageAt,
                              allowFromNow: true),
                          style: TextStyle(
                            color: isMuted
                                ? AppColors.outline
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (chat.unreadCount == 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.done_all_rounded,
                              size: 14,
                              color: isMuted
                                  ? AppColors.outline
                                  : AppColors.secondary,
                            ),
                          ),
                        if (isMuted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.volume_off_rounded,
                              size: 14,
                              color: AppColors.outline,
                            ),
                          ),
                        if (chat.lastMessageType == 'image')
                          const Icon(Icons.photo,
                              size: 14, color: AppColors.outline),
                        if (chat.lastMessageType == 'audio')
                          const Icon(Icons.mic,
                              size: 14, color: AppColors.outline),
                        if (chat.lastMessageType == 'document')
                          const Icon(Icons.attach_file,
                              size: 14, color: AppColors.outline),
                        if (chat.lastMessageType != 'text')
                          const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            chat.lastMessage.isEmpty
                                ? 'Tap to start chatting'
                                : chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMuted
                                  ? AppColors.outline
                                  : (chat.unreadCount > 0
                                      ? AppColors.onSurface
                                      : AppColors.onSurfaceVariant),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing: unread badge + dots menu
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (chat.unreadCount > 0)
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (chat.unreadCount == 0) const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showChatMenu(context, ref),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  void _showChatMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                chat.otherUser?.name ?? 'Chat',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _MenuTile(
                icon: chat.unreadCount > 0
                    ? Icons.done_all_rounded
                    : Icons.mark_chat_unread_rounded,
                label: chat.unreadCount > 0 ? 'Mark as read' : 'Mark as unread',
                onTap: () {
                  onPinToggle(chat.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: isMuted ? 'Unmute' : 'Mute',
                onTap: () {
                  onMuteToggle(chat.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                label: isPinned ? 'Unpin' : 'Pin',
                onTap: () {
                  onPinToggle(chat.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: Icons.archive_rounded,
                label: 'Archive',
                onTap: () {
                  onArchive(chat.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat archived'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete chat',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteChat(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete chat',
          style: TextStyle(color: AppColors.onSurface),
        ),
        content: Text(
          'Delete conversation with ${chat.otherUser?.name ?? "this contact"}?',
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onDelete(chat.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GROUP TILE
// ─────────────────────────────────────────────────────────────

class _GroupTile extends ConsumerWidget {
  final GroupModel group;
  final bool isPinned;
  final bool isMuted;
  final void Function(String) onPinToggle;
  final void Function(String) onMuteToggle;
  final void Function(String) onArchive;
  final void Function(String) onDelete;

  const _GroupTile({
    required this.group,
    required this.isPinned,
    required this.isMuted,
    required this.onPinToggle,
    required this.onMuteToggle,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = glassCardWrapper(
      isPinned: isPinned,
      child: InkWell(
        borderRadius: BorderRadius.circular(isPinned ? 16 : 12),
        onTap: () => context.push('/group-chat/${group.id}',
            extra: {'group': group}),
        onLongPress: () => _showGroupMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: isPinned ? 28 : 24,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    backgroundImage: group.iconUrl.isNotEmpty
                        ? NetworkImage(group.iconUrl)
                        : null,
                    child: group.iconUrl.isEmpty
                        ? Icon(Icons.group,
                            color: AppColors.secondary,
                            size: isPinned ? 26 : 22)
                        : null,
                  ),
                  if (isPinned)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.push_pin,
                            size: 10, color: AppColors.onSecondary),
                      ),
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
                        Expanded(
                          child: Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: group.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 16,
                              color: isMuted
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin_rounded,
                                size: 14, color: AppColors.secondary),
                          ),
                        Text(
                          timeago.format(group.lastMessageAt,
                              allowFromNow: true),
                          style: TextStyle(
                            color: isMuted
                                ? AppColors.outline
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMuted)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.volume_off_rounded,
                                size: 14, color: AppColors.outline),
                          ),
                        if (group.lastMessageType == 'image')
                          const Icon(Icons.photo,
                              size: 14, color: AppColors.outline),
                        if (group.lastMessageType == 'audio')
                          const Icon(Icons.mic,
                              size: 14, color: AppColors.outline),
                        if (group.lastMessageType == 'document')
                          const Icon(Icons.attach_file,
                              size: 14, color: AppColors.outline),
                        if (group.lastMessageType != 'text')
                          const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            group.lastMessage.isEmpty
                                ? 'Tap to start chatting'
                                : group.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMuted
                                  ? AppColors.outline
                                  : AppColors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (group.unreadCount > 0)
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${group.unreadCount}',
                        style: const TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (group.unreadCount == 0) const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showGroupMenu(context, ref),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  void _showGroupMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                group.name,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _MenuTile(
                icon: Icons.done_all_rounded,
                label: group.unreadCount > 0
                    ? 'Mark as read'
                    : 'Mark as unread',
                onTap: () {
                  onPinToggle(group.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: isMuted ? 'Unmute' : 'Mute',
                onTap: () {
                  onMuteToggle(group.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                label: isPinned ? 'Unpin' : 'Pin',
                onTap: () {
                  onPinToggle(group.id);
                  Navigator.pop(ctx);
                },
              ),
              _MenuTile(
                icon: Icons.archive_rounded,
                label: 'Archive',
                onTap: () {
                  onArchive(group.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group archived'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Leave group',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteGroup(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Leave group',
          style: TextStyle(color: AppColors.onSurface),
        ),
        content: Text(
          'Leave "${group.name}"?',
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onDelete(group.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MENU TILE
// ─────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.onSurface,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// THREAD ITEM HELPERS
// ─────────────────────────────────────────────────────────────

enum _ThreadKind { chat, group }

class _ThreadItem {
  final _ThreadKind kind;
  final ChatModel? chat;
  final GroupModel? group;
  final DateTime lastAt;
  final int unreadCount;

  String get id => kind == _ThreadKind.chat ? chat!.id : group!.id;

  const _ThreadItem._({
    required this.kind,
    required this.chat,
    required this.group,
    required this.lastAt,
    required this.unreadCount,
  });

  factory _ThreadItem.chat(ChatModel c) => _ThreadItem._(
        kind: _ThreadKind.chat,
        chat: c,
        group: null,
        lastAt: c.lastMessageAt,
        unreadCount: c.unreadCount,
      );

  factory _ThreadItem.group(GroupModel g) => _ThreadItem._(
        kind: _ThreadKind.group,
        chat: null,
        group: g,
        lastAt: g.lastMessageAt,
        unreadCount: g.unreadCount,
      );
}

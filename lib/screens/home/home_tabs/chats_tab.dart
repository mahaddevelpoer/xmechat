import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/user_avatar.dart';

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chats) {
        final groups = groupsAsync.valueOrNull ?? const <GroupModel>[];
        final items = <_ThreadItem>[
          ...chats.map((c) => _ThreadItem.chat(c)),
          ...groups.map((g) => _ThreadItem.group(g)),
        ]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

        if (items.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.textHint),
              SizedBox(height: 16),
              Text('No chats yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              SizedBox(height: 8),
              Text('Tap + to start a conversation', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(chatsProvider.future),
              ref.refresh(groupsProvider.future),
            ]);
          },
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              if (item.kind == _ThreadKind.group) {
                return _GroupTile(group: item.group!);
              }
              return _ChatTile(chat: item.chat!);
            },
          ),
        );
      },
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = chat.otherUser;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserAvatar(
        url: other?.avatarUrl,
        name: other?.name ?? '?',
        isOnline: other?.isOnline ?? false,
        radius: 26,
      ),
      title: Text(other?.name ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
      subtitle: Row(children: [
        if (chat.lastMessageType == 'image') const Icon(Icons.photo, size: 14, color: AppColors.textHint),
        if (chat.lastMessageType == 'audio') const Icon(Icons.mic, size: 14, color: AppColors.textHint),
        if (chat.lastMessageType == 'document') const Icon(Icons.attach_file, size: 14, color: AppColors.textHint),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            chat.lastMessage.isEmpty ? 'Tap to start chatting' : chat.lastMessage,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          timeago.format(chat.lastMessageAt, allowFromNow: true),
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        if (chat.unreadCount > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.accentGreen, shape: BoxShape.circle),
            child: Text('${chat.unreadCount}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]
      ]),
      onTap: () => context.push('/chat/${chat.id}', extra: {'user': chat.otherUser}),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  final GroupModel group;
  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.accentGreen,
        backgroundImage:
            group.iconUrl.isNotEmpty ? NetworkImage(group.iconUrl) : null,
        child: group.iconUrl.isEmpty
            ? const Icon(Icons.group, color: Colors.white)
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.group, size: 16, color: AppColors.textHint),
        ],
      ),
      subtitle: Row(children: [
        if (group.lastMessageType == 'image')
          const Icon(Icons.photo, size: 14, color: AppColors.textHint),
        if (group.lastMessageType == 'audio')
          const Icon(Icons.mic, size: 14, color: AppColors.textHint),
        if (group.lastMessageType == 'document')
          const Icon(Icons.attach_file, size: 14, color: AppColors.textHint),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            group.lastMessage.isEmpty ? 'Tap to start chatting' : group.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          timeago.format(group.lastMessageAt, allowFromNow: true),
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        if (group.unreadCount > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration:
                const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
            child: Text(
              '${group.unreadCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]
      ]),
      onTap: () => context.push('/group-chat/${group.id}', extra: {'group': group}),
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

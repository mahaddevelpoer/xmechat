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
    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (chats) {
        if (chats.isEmpty) {
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
          onRefresh: () async => ref.refresh(chatsProvider),
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) => _ChatTile(chat: chats[i]),
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
    final me = ref.read(authServiceProvider).currentUserId;
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

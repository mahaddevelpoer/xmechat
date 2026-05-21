import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Select Contact')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) {
              final user = users[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: UserAvatar(url: user.avatarUrl, name: user.name, isOnline: user.isOnline, radius: 26),
                title: Text(user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
                subtitle: Text(user.phoneInfo.isEmpty ? user.email : user.phoneInfo,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined, color: AppColors.accentGreen),
                    onPressed: () async {
                      final callId = await ref.read(webrtcServiceProvider).initiateCall(user.id, isVideo: true);
                      if (!context.mounted) return;
                      context.push('/video-call/$callId', extra: {'isCaller': true, 'user': user});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_outlined, color: AppColors.accentGreen),
                    onPressed: () async {
                      final callId = await ref.read(webrtcServiceProvider).initiateCall(user.id, isVideo: false);
                      if (!context.mounted) return;
                      context.push('/voice-call/$callId', extra: {'isCaller': true, 'user': user});
                    },
                  ),
                ]),
                onTap: () async {
                  final chatId = await ref.read(chatServiceProvider).getOrCreateChat(user.id);
                  if (!context.mounted) return;
                  context.push('/chat/$chatId', extra: {'user': user});
                },
              );
            },
          );
        },
      ),
    );
  }
}

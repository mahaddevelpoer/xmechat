import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.read(authServiceProvider).currentUserId;
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: FutureBuilder(
        future: ref.read(chatServiceProvider).getUserById(userId),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final user = snap.data!;
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.primaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.primaryGreen,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white24,
                        backgroundImage: user.avatarUrl.isNotEmpty
                            ? NetworkImage(user.avatarUrl)
                            : null,
                        child: user.avatarUrl.isEmpty
                            ? Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.bio.isNotEmpty ? user.bio : 'Hey there! I am using XmeChat.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(children: [
                // Info section
                Container(
                  color: Colors.white,
                  child: Column(children: [
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'mobile',
                        value: user.phoneInfo.isNotEmpty ? user.phoneInfo : 'Not set'),
                    const Divider(indent: 56, height: 1),
                    _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'email',
                        value: user.email),
                    const Divider(indent: 56, height: 1),
                    _InfoRow(
                      icon: Icons.circle,
                      iconColor: user.isOnline ? AppColors.online : AppColors.textHint,
                      label: 'status',
                      value: user.isOnline ? 'Online' : 'last seen ${_lastSeen(user.lastSeen)}',
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.chat_bubble_outline,
                        label: 'Message',
                        onTap: () async {
                          final chatId =
                              await ref.read(chatServiceProvider).getOrCreateChat(userId);
                          if (!context.mounted) return;
                          context.push('/chat/$chatId', extra: {'user': user});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.call_outlined,
                        label: 'Call',
                        onTap: () async {
                          if (userId == myId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Cannot call yourself.'),
                                  backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          final latestUser =
                              await ref.read(chatServiceProvider).getUserById(userId);
                          if (!context.mounted) return;
                          if (latestUser == null || !latestUser.isOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.name} is offline. Cannot initiate call.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          final callId = await ref
                              .read(webrtcServiceProvider)
                              .initiateCall(userId, isVideo: false);
                          if (!context.mounted) return;
                          context.push('/voice-call/$callId',
                              extra: {'isCaller': true, 'user': user});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        onTap: () async {
                          if (userId == myId) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Cannot call yourself.'),
                                  backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          final latestUser =
                              await ref.read(chatServiceProvider).getUserById(userId);
                          if (!context.mounted) return;
                          if (latestUser == null || !latestUser.isOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.name} is offline. Cannot initiate call.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          final callId = await ref
                              .read(webrtcServiceProvider)
                              .initiateCall(userId, isVideo: true);
                          if (!context.mounted) return;
                          context.push('/video-call/$callId',
                              extra: {'isCaller': true, 'user': user});
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                // Block user
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.block, color: AppColors.error),
                    title: Text('Block ${user.name}',
                        style: const TextStyle(color: AppColors.error)),
                    onTap: () async {
                      await ref.read(chatServiceProvider).blockUser(userId);
                      if (!context.mounted) return;
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${user.name} blocked')));
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  String _lastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value, this.iconColor});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.textHint, size: 20),
        title: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: Text(label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)
            ]),
        child: Column(children: [
          Icon(icon, color: AppColors.primaryGreen, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

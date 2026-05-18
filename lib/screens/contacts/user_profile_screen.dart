import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: FutureBuilder(
        future: ref.read(chatServiceProvider).getUserById(userId),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final user = snap.data!;
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: user.avatarUrl.isNotEmpty
                  ? Image.network(user.avatarUrl, fit: BoxFit.cover)
                  : Container(color: AppColors.primaryGreen,
                      child: const Icon(Icons.person, size: 80, color: Colors.white54)),
              ),
            ),
            SliverToBoxAdapter(child: Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(user.bio.isEmpty ? 'Hey there! I am using XmeChat.' : user.bio,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 8),
              Container(
                color: Colors.white,
                child: Column(children: [
                  _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phoneInfo.isEmpty ? 'Not set' : user.phoneInfo),
                  const Divider(indent: 56, height: 1),
                  _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
                  const Divider(indent: 56, height: 1),
                  _InfoRow(
                    icon: Icons.circle,
                    iconColor: user.isOnline ? AppColors.online : AppColors.textHint,
                    label: 'Status',
                    value: user.isOnline ? 'Online' : 'Last seen ${_lastSeen(user.lastSeen)}',
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: _ActionBtn(
                    icon: Icons.chat_bubble_outline,
                    label: 'Message',
                    onTap: () async {
                      final chatId = await ref.read(chatServiceProvider).getOrCreateChat(userId);
                      if (!context.mounted) return;
                      context.push('/chat/$chatId', extra: {'user': user});
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionBtn(
                    icon: Icons.call_outlined,
                    label: 'Call',
                    onTap: () async {
                      final callId = await ref.read(webrtcServiceProvider).initiateCall(userId, isVideo: false);
                      if (!context.mounted) return;
                      context.push('/voice-call/$callId', extra: {'isCaller': true, 'user': user});
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ActionBtn(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    onTap: () async {
                      final callId = await ref.read(webrtcServiceProvider).initiateCall(userId, isVideo: true);
                      if (!context.mounted) return;
                      context.push('/video-call/$callId', extra: {'isCaller': true, 'user': user});
                    },
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.block, color: AppColors.error),
                  title: Text('Block ${user.name}', style: const TextStyle(color: AppColors.error)),
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
            ])),
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
  const _InfoRow({required this.icon, required this.label, required this.value, this.iconColor});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor ?? AppColors.textHint, size: 20),
    title: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
    subtitle: Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)]),
        child: Column(children: [
          Icon(icon, color: AppColors.primaryGreen, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class ChatInfoScreen extends ConsumerWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: FutureBuilder(
        future: ref.read(chatServiceProvider).fetchChats(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final myId = ref.read(authServiceProvider).currentUserId;
          final chat = snap.data!.firstWhere((c) => c.id == chatId,
            orElse: () => throw Exception('Chat not found'));
          final other = chat.otherUser;
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: other?.avatarUrl.isNotEmpty == true
                  ? Image.network(other!.avatarUrl, fit: BoxFit.cover)
                  : Container(color: AppColors.primaryGreen,
                    child: const Icon(Icons.person, size: 80, color: Colors.white70)),
              ),
            ),
            SliverToBoxAdapter(child: Column(children: [
              const SizedBox(height: 20),
              Text(other?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(other?.email ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              if (other?.phoneInfo.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(other!.phoneInfo, style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 20),
              _InfoTile(icon: Icons.info_outline, title: 'About', subtitle: other?.bio.isEmpty == true ? 'Hey there! I am using XmeChat.' : other?.bio ?? ''),
              _InfoTile(icon: Icons.phone_outlined, title: 'Phone', subtitle: other?.phoneInfo.isEmpty == true ? 'Not set' : other?.phoneInfo ?? 'Not set'),
              const Divider(),
              _InfoTile(icon: Icons.notifications_outlined, title: 'Mute notifications', subtitle: 'On', trailing: Switch(value: false, onChanged: (_) {}, activeColor: AppColors.accentGreen)),
              _InfoTile(icon: Icons.image_outlined, title: 'Media, links and docs', subtitle: '', onTap: () {}),
              _InfoTile(icon: Icons.star_outline, title: 'Starred messages', subtitle: '', onTap: () {}),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.error),
                title: Text('Block ${other?.name ?? "User"}', style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  if (other == null) return;
                  await ref.read(chatServiceProvider).blockUser(other.id);
                  if (!context.mounted) return;
                  context.pop();
                },
              ),
              const SizedBox(height: 30),
            ])),
          ]);
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _InfoTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

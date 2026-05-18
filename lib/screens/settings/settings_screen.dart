import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) => ListView(children: [
          // Profile card
          GestureDetector(
            onTap: () => context.push('/edit-profile'),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(children: [
                UserAvatar(url: user?.avatarUrl, name: user?.name ?? '?', radius: 30),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? 'Loading...', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(user?.bio.isEmpty == true ? 'Hey there! I am using XmeChat.' : user?.bio ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(user?.phoneInfo ?? '', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                ])),
                const Icon(Icons.qr_code, color: AppColors.primaryGreen, size: 28),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(items: [
            _SettingsTile(icon: Icons.key, label: 'Account', subtitle: 'Security notifications, change number', onTap: () {}),
            _SettingsTile(icon: Icons.lock_outline, label: 'Privacy', subtitle: 'Block contacts, disappearing messages', onTap: () {}),
            _SettingsTile(icon: Icons.chat_bubble_outline, label: 'Chats', subtitle: 'Theme, wallpapers, chat history', onTap: () {}),
            _SettingsTile(icon: Icons.notifications_outlined, label: 'Notifications', subtitle: 'Message, group & call tones', onTap: () {}),
          ]),
          const SizedBox(height: 8),
          _SettingsSection(items: [
            _SettingsTile(icon: Icons.dark_mode_outlined, label: 'Dark Mode',
              trailing: Switch(
                value: isDark,
                activeColor: AppColors.accentGreen,
                onChanged: (v) => ref.read(themeProvider.notifier).state = v,
              ),
            ),
            _SettingsTile(icon: Icons.storage_outlined, label: 'Storage and data', subtitle: 'Network usage, auto-download', onTap: () {}),
            _SettingsTile(icon: Icons.help_outline, label: 'Help', subtitle: 'Help centre, contact us, privacy policy', onTap: () {}),
          ]),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500)),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authServiceProvider).signOut();
                  if (!context.mounted) return;
                  context.go('/login');
                }
              },
            ),
          ),
          const SizedBox(height: 30),
          const Center(child: Text('XmeChat v1.0.0', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<Widget> items;
  const _SettingsSection({required this.items});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Column(children: items.expand((item) => [item, const Divider(indent: 56, height: 1)]).toList()..removeLast()),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: AppColors.textHint, fontSize: 12)) : null,
    trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textHint) : null),
    onTap: onTap,
  );
}

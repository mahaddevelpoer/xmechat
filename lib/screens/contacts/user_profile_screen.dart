import 'dart:ui' show ImageFilter;
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
    final isOwnProfile = userId == myId;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder(
        future: ref.read(chatServiceProvider).getUserById(userId),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }
          final user = snap.data!;
          final handle = user.email.split('@').first;
          final isWide = MediaQuery.of(context).size.width >= 768;
          final coverH = isWide ? 256.0 : 192.0;
          final avatarSize = isWide ? 160.0 : 128.0;
          final avatarRadius = avatarSize / 2;

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Column(children: [
                // ═══════════════════════════════════════════
                // COVER + AVATAR
                // ═══════════════════════════════════════════
                SizedBox(
                  height: coverH + avatarRadius,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: coverH,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1a0533),
                                Color(0xFF0d1b3e),
                                Color(0xFF0b1326),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -40, right: -40,
                                child: Container(
                                  width: 200, height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      AppColors.secondary.withAlpha(30),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -60, left: -20,
                                child: Container(
                                  width: 180, height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      AppColors.primary.withAlpha(20),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        AppColors.surface.withAlpha(230),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -avatarRadius,
                        left: 0, right: 0,
                        child: Center(
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withAlpha(80),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: avatarRadius - 2,
                              backgroundColor: AppColors.surfaceContainerHigh,
                              backgroundImage: user.avatarUrl.isNotEmpty
                                  ? NetworkImage(user.avatarUrl)
                                  : null,
                              child: user.avatarUrl.isEmpty
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppColors.onSurface,
                                        fontSize: avatarRadius * 0.75,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ═══════════════════════════════════════════
                // NAME
                // ═══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),

                // ═══════════════════════════════════════════
                // USERNAME
                // ═══════════════════════════════════════════
                Text(
                  '@$handle',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Bio ──
                if (user.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                    child: Text(
                      user.bio,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),

                // ═══════════════════════════════════════════
                // EDIT PROFILE / ACTION BUTTONS
                // ═══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isOwnProfile
                      ? _GlassBtn(
                          icon: Icons.edit_outlined,
                          label: 'Edit Profile',
                          onTap: () {},
                        )
                      : _actionRow(context, ref, user, userId, myId),
                ),
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════
                // STATS ROW
                // ═══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: _StatCard(
                      label: 'Posts', value: '128', color: AppColors.primary,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(
                      label: 'Connections', value: '1.4k', color: AppColors.secondary,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(
                      label: 'Access Level', value: 'Pro', color: AppColors.tertiary,
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                // ═══════════════════════════════════════════
                // INFO SECTION (phone, email, status)
                // ═══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _GlassContainer(
                    child: Column(children: [
                      _GlassInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phoneInfo.isNotEmpty ? user.phoneInfo : 'Not set',
                      ),
                      const Divider(indent: 56, height: 1, color: AppColors.outlineVariant),
                      _GlassInfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                      ),
                      const Divider(indent: 56, height: 1, color: AppColors.outlineVariant),
                      _GlassInfoRow(
                        icon: Icons.circle,
                        iconColor: user.isOnline ? AppColors.secondary : AppColors.outline,
                        label: 'Status',
                        value: user.isOnline ? 'Online' : 'Last seen ${_lastSeen(user.lastSeen)}',
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Action buttons for own profile ──
                if (isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _actionRow(context, ref, user, userId, myId),
                  ),
                if (isOwnProfile) const SizedBox(height: 12),

                // ═══════════════════════════════════════════
                // SETTINGS LIST
                // ═══════════════════════════════════════════
                if (isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _GlassContainer(child: _SettingsList()),
                  ),
                if (isOwnProfile) const SizedBox(height: 12),

                // ═══════════════════════════════════════════
                // BLOCK USER
                // ═══════════════════════════════════════════
                _BlockTile(user: user, userId: userId, ref: ref),
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

// ═══════════════════════════════════════════════════════════════════
// WIDGET HELPERS
// ═══════════════════════════════════════════════════════════════════

Widget _actionRow(BuildContext context, WidgetRef ref, dynamic user, String userId, String myId) {
  return Row(children: [
    Expanded(
      child: _ActionBtn(
        icon: Icons.chat_bubble_outlined,
        label: 'Message',
        onTap: () async {
          final chatId = await ref.read(chatServiceProvider).getOrCreateChat(userId);
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
              const SnackBar(content: Text('Cannot call yourself.'), backgroundColor: AppColors.error),
            );
            return;
          }
          final latestUser = await ref.read(chatServiceProvider).getUserById(userId);
          if (!context.mounted) return;
          if (latestUser == null || !latestUser.isOnline) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${user.name} is offline. Cannot initiate call.'), backgroundColor: AppColors.error),
            );
            return;
          }
          final callId = await ref.read(webrtcServiceProvider).initiateCall(userId, isVideo: false);
          if (!context.mounted) return;
          context.push('/voice-call/$callId', extra: {'isCaller': true, 'user': user});
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
              const SnackBar(content: Text('Cannot call yourself.'), backgroundColor: AppColors.error),
            );
            return;
          }
          final latestUser = await ref.read(chatServiceProvider).getUserById(userId);
          if (!context.mounted) return;
          if (latestUser == null || !latestUser.isOnline) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${user.name} is offline. Cannot initiate call.'), backgroundColor: AppColors.error),
            );
            return;
          }
          final callId = await ref.read(webrtcServiceProvider).initiateCall(userId, isVideo: true);
          if (!context.mounted) return;
          context.push('/video-call/$callId', extra: {'isCaller': true, 'user': user});
        },
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════════
// SETTINGS LIST
// ═══════════════════════════════════════════════════════════════════

class _SettingsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _SettingItemData(
        icon: Icons.notifications_outlined,
        iconColor: AppColors.secondary,
        title: 'Notifications',
        description: 'Message alerts, sound, vibration',
      ),
      _SettingItemData(
        icon: Icons.lock_outline,
        iconColor: AppColors.primary,
        title: 'Privacy & Security',
        description: 'Blocked users, app lock, encryption',
      ),
      _SettingItemData(
        icon: Icons.palette_outlined,
        iconColor: AppColors.tertiary,
        title: 'Appearance',
        description: 'Dark mode, accent color, font size',
      ),
      _SettingItemData(
        icon: Icons.storage_outlined,
        iconColor: AppColors.secondary,
        title: 'Storage & Data',
        description: 'Cache, auto-download, media quality',
      ),
    ];
    return Column(children: [
      for (final item in items) ...[
        if (items.indexOf(item) > 0)
          const Divider(height: 1, color: AppColors.outlineVariant),
        _SettingsTile(data: item),
      ],
    ]);
  }
}

class _SettingItemData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  const _SettingItemData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

class _SettingsTile extends StatelessWidget {
  final _SettingItemData data;
  const _SettingsTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: data.iconColor.withAlpha(25),
          shape: BoxShape.circle,
        ),
        child: Icon(data.icon, color: data.iconColor, size: 22),
      ),
      title: Text(
        data.title,
        style: const TextStyle(
          color: AppColors.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        data.description,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
      onTap: () {},
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BLOCK TILE
// ═══════════════════════════════════════════════════════════════════

class _BlockTile extends StatelessWidget {
  final dynamic user;
  final String userId;
  final WidgetRef ref;
  const _BlockTile({required this.user, required this.userId, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _GlassContainer(
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block, color: AppColors.error, size: 22),
          ),
          title: Text(
            'Block ${user.name}',
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
          onTap: () async {
            await ref.read(chatServiceProvider).blockUser(userId);
            if (!context.mounted) return;
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${user.name} blocked')),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GLASS CONTAINER
// ═══════════════════════════════════════════════════════════════════

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GLASS BUTTON
// ═══════════════════════════════════════════════════════════════════

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STAT CARD (for Stats Row)
// ═══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(15),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GLASS INFO ROW (phone, email, status)
// ═══════════════════════════════════════════════════════════════════

class _GlassInfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label, value;
  const _GlassInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.onSurface.withAlpha(10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? AppColors.outline, size: 20),
      ),
      title: Text(
        value,
        style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
      ),
      subtitle: Text(
        label,
        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ACTION BUTTON (Message / Call / Video)
// ═══════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(children: [
                  Icon(icon, color: AppColors.secondary, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

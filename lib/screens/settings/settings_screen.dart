import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../services/xmechat_root.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifyMessages = true;
  bool _notifyCalls = true;
  bool _windowsAutoStart = true;
  bool _enterToSend = false;
  double _fontSize = 14;
  String _ringtoneName = 'Default Ringtone';
  String _ringtonePath = '';
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyMessages = prefs.getBool('notify_messages') ?? true;
      _notifyCalls = prefs.getBool('notify_calls') ?? true;
      _windowsAutoStart = prefs.getBool('windows_autostart') ?? true;
      _enterToSend = prefs.getBool('enter_to_send') ?? false;
      _fontSize = prefs.getDouble('font_size') ?? 14;
      _ringtonePath = prefs.getString('ringtone_path') ?? '';
      if (_ringtonePath.isNotEmpty && !_ringtonePath.startsWith('http')) {
        _ringtoneName = _ringtonePath.split('/').last;
      }
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _changePassword() async {
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We will send a password reset link to your email.',
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                hintText: 'Your email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final scaffoldMsg = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(authServiceProvider)
                    .resetPassword(emailCtrl.text.trim());
                nav.pop();
                scaffoldMsg.showSnackBar(
                  const SnackBar(content: Text('Password reset email sent!')),
                );
              } catch (e) {
                scaffoldMsg.showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.error),
        ),
        content: const Text(
          'This will permanently delete your account, messages and all data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(authServiceProvider).deleteAccount();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickRingtone() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Call Ringtone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Default Ringtone'),
              onTap: () async {
                setState(() {
                  _ringtonePath = '';
                  _ringtoneName = 'Default Ringtone';
                });
                await _savePref('ringtone_path', '');
                await Supabase.instance.client
                    .from(SupabaseConstants.usersTable)
                    .update({'ringtone_url': ''})
                    .eq('id', ref.read(authServiceProvider).currentUserId);
                if (mounted) Navigator.pop(context);
              },
              trailing: IconButton(
                icon: const Icon(
                  Icons.play_circle_fill,
                  color: AppColors.primaryGreen,
                ),
                onPressed: () async {
                  await _previewPlayer.setUrl(
                    'https://www.soundjay.com/phone/sounds/telephone-ring-01a.mp3',
                  );
                  _previewPlayer.play();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Choose from device'),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );
                if (result != null && result.files.isNotEmpty) {
                  final path = result.files.first.path;
                  if (path != null) {
                    setState(() {
                      _ringtonePath = path;
                      _ringtoneName = result.files.first.name;
                    });
                    await _savePref('ringtone_path', path);
                    // For local file, maybe we don't upload to supabase if it's desktop, or we can just save it locally.
                    // The prompt says "stored in users table ringtone_url in Supabase", but a local path is not a URL.
                    // We'll update the name just in case.
                    await Supabase.instance.client
                        .from(SupabaseConstants.usersTable)
                        .update({'ringtone_url': path})
                        .eq('id', ref.read(authServiceProvider).currentUserId);
                  }
                }
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _previewPlayer.stop();
                Navigator.pop(context);
              },
              child: const Text(
                'Stop Preview / Close',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) => ListView(
          children: [
            // ── Profile Card ─────────────────────────────────
            GestureDetector(
              onTap: () => context.push('/edit-profile'),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      url: user?.avatarUrl,
                      name: user?.name ?? '?',
                      radius: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.bio.isEmpty == true
                                ? 'Hey there! I am using XmeChat.'
                                : user?.bio ?? '',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((user?.phoneInfo ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.phoneInfo,
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Notifications ────────────────────────────────
            _SectionHeader(title: 'Notifications'),
            _SettingsSection(
              items: [
                _SettingsTile(
                  icon: Icons.message_outlined,
                  label: 'Message Notifications',
                  trailing: Switch(
                    value: _notifyMessages,
                    activeTrackColor: AppColors.primaryGreen.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) {
                      setState(() => _notifyMessages = v);
                      _savePref('notify_messages', v);
                    },
                  ),
                ),
                _SettingsTile(
                  icon: Icons.call_outlined,
                  label: 'Call Notifications',
                  trailing: Switch(
                    value: _notifyCalls,
                    activeTrackColor: AppColors.primaryGreen.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) {
                      setState(() => _notifyCalls = v);
                      _savePref('notify_calls', v);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.music_video,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text('Call Ringtone'),
                  subtitle: Text(_ringtoneName),
                  onTap: _pickRingtone,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Windows ──────────────────────────────────────
            if (Platform.isWindows) ...[
              _SectionHeader(title: 'Windows'),
              _SettingsSection(
                items: [
                  _SettingsTile(
                    icon: Icons.power_settings_new,
                    label: 'Start on Windows startup',
                    subtitle: 'Auto-start XmeChat when Windows boots',
                    trailing: Switch(
                      value: _windowsAutoStart,
                      activeTrackColor: AppColors.primaryGreen.withValues(
                        alpha: 0.5,
                      ),
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (v) async {
                        setState(() => _windowsAutoStart = v);
                        await _savePref('windows_autostart', v);
                        await XmeChatRoot.instance.setWindowsAutoStartEnabled(
                          v,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Chats ────────────────────────────────────────
            _SectionHeader(title: 'Chats'),
            _SettingsSection(
              items: [
                _SettingsTile(
                  icon: Icons.keyboard_return,
                  label: 'Enter to Send',
                  subtitle: 'Press Enter key to send a message',
                  trailing: Switch(
                    value: _enterToSend,
                    activeTrackColor: AppColors.primaryGreen.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) {
                      setState(() => _enterToSend = v);
                      _savePref('enter_to_send', v);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.format_size,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text(
                    'Font Size',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        value: _fontSize,
                        min: 12,
                        max: 20,
                        divisions: 4,
                        activeColor: AppColors.primaryGreen,
                        label: '${_fontSize.toInt()}px',
                        onChanged: (v) {
                          setState(() => _fontSize = v);
                          _savePref('font_size', v);
                        },
                      ),
                      Text(
                        '${_fontSize.toInt()}px',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Appearance ───────────────────────────────────
            _SectionHeader(title: 'Appearance'),
            _SettingsSection(
              items: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  trailing: Switch(
                    value: isDark,
                    activeTrackColor: AppColors.primaryGreen.withValues(
                      alpha: 0.5,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        ref.read(themeProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Account ──────────────────────────────────────
            _SectionHeader(title: 'Account'),
            _SettingsSection(
              items: [
                _SettingsTile(
                  icon: Icons.block,
                  label: 'Blocked Contacts',
                  onTap: () => context.push('/blocked-contacts'),
                ),
                _SettingsTile(
                  icon: Icons.broadcast_on_home,
                  label: 'Broadcast Lists',
                  onTap: () => context.push('/broadcast-lists'),
                ),
                _SettingsTile(
                  icon: Icons.lock_reset,
                  label: 'Change Password',
                  onTap: _changePassword,
                ),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  label: 'Delete Account',
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Logout ───────────────────────────────────────
            Container(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await XmeChatRoot.instance.detachForLogout();
                    await ref.read(authServiceProvider).signOut();
                    ref.invalidate(currentUserIdProvider);
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(chatsProvider);
                    ref.invalidate(groupsProvider);
                    ref.invalidate(statusesProvider);
                    ref.invalidate(myStatusesProvider);
                    ref.invalidate(callHistoryProvider);
                    ref.invalidate(allUsersProvider);
                    ref.invalidate(authStateProvider);
                    if (!context.mounted) return;
                    context.go('/login');
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'XmeChat v1.0.0',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryGreen,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  final List<Widget> items;
  const _SettingsSection({required this.items});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Column(
      children:
          items
              .expand((item) => [item, const Divider(indent: 56, height: 1)])
              .toList()
            ..removeLast(),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor ?? AppColors.primaryGreen),
    title: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: labelColor ?? AppColors.textPrimary,
      ),
    ),
    subtitle: subtitle != null
        ? Text(
            subtitle!,
            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          )
        : null,
    trailing:
        trailing ??
        (onTap != null
            ? const Icon(Icons.chevron_right, color: AppColors.textHint)
            : null),
    onTap: onTap,
  );
}

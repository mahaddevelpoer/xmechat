import 'dart:ui';
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

  bool _onlineStatus = true;
  bool _readReceipts = true;
  bool _lastSeen = true;
  String _notificationSoundName = 'Default';
  String _notificationSoundPath = '';
  String _defaultStoreName = 'Auto';
  String _defaultStorePath = '';

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
      _onlineStatus = prefs.getBool('online_status') ?? true;
      _readReceipts = prefs.getBool('read_receipts') ?? true;
      _lastSeen = prefs.getBool('last_seen') ?? true;
      _notificationSoundPath = prefs.getString('notification_sound_path') ?? '';
      _defaultStorePath = prefs.getString('default_store_path') ?? '';
      if (_ringtonePath.isNotEmpty && !_ringtonePath.startsWith('http')) {
        _ringtoneName = _ringtonePath.split('/').last;
      }
      if (_notificationSoundPath.isNotEmpty &&
          !_notificationSoundPath.startsWith('http')) {
        _notificationSoundName = _notificationSoundPath.split('/').last;
      }
      if (_defaultStorePath.isNotEmpty) {
        _defaultStoreName = _defaultStorePath.split(r'\').last;
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
                  const SnackBar(
                      content: Text('Password reset email sent!')),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error),
      );
    }
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
                    .eq('id',
                        ref.read(authServiceProvider).currentUserId);
                if (mounted) Navigator.pop(context);
              },
              trailing: IconButton(
                icon: const Icon(
                  Icons.play_circle_fill,
                  color: AppColors.secondary,
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
                    await Supabase.instance.client
                        .from(SupabaseConstants.usersTable)
                        .update({'ringtone_url': path})
                        .eq('id',
                            ref.read(authServiceProvider).currentUserId);
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

  Future<void> _pickNotificationSound() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notification Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Default'),
              onTap: () async {
                setState(() {
                  _notificationSoundPath = '';
                  _notificationSoundName = 'Default';
                });
                await _savePref('notification_sound_path', '');
                if (mounted) Navigator.pop(context);
              },
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
                      _notificationSoundPath = path;
                      _notificationSoundName = result.files.first.name;
                    });
                    await _savePref('notification_sound_path', path);
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
              child: const Text('Close',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDefaultStore() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _defaultStorePath = result;
        _defaultStoreName = result.split(r'\').last;
      });
      await _savePref('default_store_path', result);
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── Glass Card Builder ───────────────────────────────────────

  Widget _glassCard({
    required Widget child,
    double borderRadius = 16,
    double blur = 30,
    Color bg = AppColors.glassBg,
    EdgeInsetsGeometry? padding,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                border ?? Border.all(color: AppColors.glassBorder),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Setting Item Widget ──────────────────────────────────────

  Widget _settingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconBgColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor ??
                    AppColors.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? AppColors.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ── Section Wrapper ──────────────────────────────────────────

  Widget _sectionCard({required Widget child}) {
    return _glassCard(
      borderRadius: 16,
      blur: 30,
      bg: AppColors.glassBg,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.glassBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Configure your experience',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.secondary),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── Profile Card ──────────────────────────────
            _glassCard(
              borderRadius: 16,
              blur: 30,
              bg: AppColors.glassBg,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      url: user?.avatarUrl,
                      name: user?.name ?? '?',
                      radius: 38,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/edit-profile'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary
                            .withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Preferences ──────────────────────────────
            _sectionHeader('Preferences'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.format_size,
                    title: 'Font Size',
                    subtitle: '${_fontSize.toInt()}px',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 0),
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 20,
                      divisions: 4,
                      activeColor: AppColors.secondary,
                      inactiveColor:
                          AppColors.outlineVariant,
                      label: '${_fontSize.toInt()}px',
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        _savePref('font_size', v);
                      },
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.keyboard_return,
                    title: 'Enter to Send',
                    subtitle: 'Press Enter to send a message',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _enterToSend,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(() => _enterToSend = v);
                          _savePref('enter_to_send', v);
                        },
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: isDark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    title: 'Theme',
                    subtitle:
                        isDark ? 'Dark Mode' : 'Light Mode',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: isDark,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) =>
                            ref.read(themeProvider.notifier)
                                .state = v,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Notifications ────────────────────────────
            _sectionHeader('Notifications'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.message_outlined,
                    title: 'Message Notifications',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _notifyMessages,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(
                              () => _notifyMessages = v);
                          _savePref('notify_messages', v);
                        },
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.call_outlined,
                    title: 'Call Notifications',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _notifyCalls,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(() => _notifyCalls = v);
                          _savePref('notify_calls', v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Media ────────────────────────────────────
            _sectionHeader('Media'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.folder_outlined,
                    title: 'Default Store',
                    subtitle: _defaultStoreName,
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: _pickDefaultStore,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.ring_volume_outlined,
                    title: 'Voice Ringtone',
                    subtitle: _ringtoneName,
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: _pickRingtone,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notification Sound',
                    subtitle: _notificationSoundName,
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: _pickNotificationSound,
                  ),
                ],
              ),
            ),

            // ── Windows ──────────────────────────────────
            if (Platform.isWindows) ...[
              const SizedBox(height: 6),
              _sectionHeader('Windows'),
              _sectionCard(
                child: _settingItem(
                  icon: Icons.power_settings_new,
                  title: 'Start on Windows startup',
                  subtitle:
                      'Auto-start XmeChat when Windows boots',
                  iconBgColor: AppColors.primaryContainer,
                  iconColor: AppColors.primaryFixed,
                  trailing: SizedBox(
                    height: 24,
                    child: Switch(
                      value: _windowsAutoStart,
                      activeTrackColor: AppColors.secondary
                          .withValues(alpha: 0.5),
                      activeThumbColor:
                          AppColors.secondary,
                      onChanged: (v) async {
                        setState(
                            () => _windowsAutoStart = v);
                        await _savePref(
                            'windows_autostart', v);
                        await XmeChatRoot.instance
                            .setWindowsAutoStartEnabled(
                                v);
                      },
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),

            // ── Privacy ──────────────────────────────────
            _sectionHeader('Privacy'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.circle_outlined,
                    title: 'Online Status',
                    subtitle: 'Show when you are online',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _onlineStatus,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(
                              () => _onlineStatus = v);
                          _savePref('online_status', v);
                        },
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.done_all_outlined,
                    title: 'Read Receipts',
                    subtitle:
                        'Let others know you read their messages',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _readReceipts,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(
                              () => _readReceipts = v);
                          _savePref('read_receipts', v);
                        },
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.visibility_outlined,
                    title: 'Last Seen',
                    subtitle:
                        'Show when you were last active',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: SizedBox(
                      height: 24,
                      child: Switch(
                        value: _lastSeen,
                        activeTrackColor: AppColors.secondary
                            .withValues(alpha: 0.5),
                        activeThumbColor:
                            AppColors.secondary,
                        onChanged: (v) {
                          setState(() => _lastSeen = v);
                          _savePref('last_seen', v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Account ──────────────────────────────────
            _sectionHeader('Account'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.block,
                    title: 'Blocked Contacts',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: () =>
                        context.push('/blocked-contacts'),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.broadcast_on_home,
                    title: 'Broadcast Lists',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: () =>
                        context.push('/broadcast-lists'),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.lock_reset,
                    title: 'Change Password',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: _changePassword,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.delete_outline,
                    title: 'Delete Account',
                    iconBgColor:
                        AppColors.errorContainer.withValues(alpha: 0.3),
                    iconColor: AppColors.error,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── About ────────────────────────────────────
            _sectionHeader('About'),
            _sectionCard(
              child: Column(
                children: [
                  _settingItem(
                    icon: Icons.info_outline,
                    title: 'Version',
                    subtitle: 'XmeChat v1.0.0',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.description_outlined,
                    title: 'Licenses',
                    subtitle: 'Open-source licenses',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'XmeChat',
                      applicationVersion: 'v1.0.0',
                      applicationLegalese: '© 2026 XmeChat',
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.glassBorder,
                  ),
                  _settingItem(
                    icon: Icons.phone_android_outlined,
                    title: 'App Info',
                    subtitle: 'XmeChat Messenger',
                    iconBgColor: AppColors.primaryContainer,
                    iconColor: AppColors.primaryFixed,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Logout ──────────────────────────────────
            _glassCard(
              borderRadius: 16,
              blur: 30,
              bg: AppColors.glassBg,
              child: _settingItem(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                iconBgColor: AppColors.errorContainer
                    .withValues(alpha: 0.3),
                iconColor: AppColors.error,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.error,
                  size: 20,
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text(
                          'Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.error,
                            minimumSize: Size.zero,
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10),
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await XmeChatRoot.instance
                        .detachForLogout();
                    await ref
                        .read(authServiceProvider)
                        .signOut();
                    ref.invalidate(
                        currentUserIdProvider);
                    ref.invalidate(
                        currentUserProvider);
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;
  Map<String, dynamic> _prefs = {};
  bool _loading = true;
  late final SettingsService _settingsService;
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    final uid = _auth.currentUserId;
    _settingsService = SettingsService(uid);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _settingsService.fetchAll();
      if (mounted) setState(() { _prefs = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPref(String key, dynamic value) async {
    await _settingsService.save(key, value);
    setState(() => _prefs[key] = value);
  }

  bool _getBool(String key, [bool defaultValue = true]) => _prefs[key] as bool? ?? defaultValue;
  double _getDouble(String key, [double defaultValue = 14]) => _prefs[key] as double? ?? defaultValue;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          _buildNav(),
          Expanded(child: _buildPanel()),
        ],
      ),
    );
  }

  Widget _buildNav() {
    final items = [
      ('Profile', Icons.person_outlined),
      ('Notifications', Icons.notifications_outlined),
      ('Chats', Icons.chat_bubble_outline),
      ('Calls', Icons.call_outlined),
      ('Account', Icons.shield_outlined),
      ('About', Icons.info_outlined),
    ];
    return Container(
      width: 240,
      color: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (_, i) {
          final active = _selectedTab == i;
          return ListTile(
            dense: true,
            leading: Icon(items[i].$2, size: 20, color: active ? AppColors.accent : AppColors.textHint),
            title: Text(items[i].$1, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
            selected: active,
            selectedTileColor: AppColors.accentLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            onTap: () => setState(() => _selectedTab = i),
          );
        },
      ),
    );
  }

  Widget _buildPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: [
          _buildProfilePanel(),
          _buildNotificationsPanel(),
          _buildChatsPanel(),
          _buildCallsPanel(),
          _buildAccountPanel(),
          _buildAboutPanel(),
        ][_selectedTab],
      ),
    );
  }

  Widget _buildProfilePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile', style: AppText.heading),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.accentLight,
                child: Text('M', style: TextStyle(fontSize: 32, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: () {}, child: const Text('Change Profile Photo')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _readOnlyField('Name', _auth.currentUser?.email ?? 'User'),
        _readOnlyField('Email', _auth.currentUser?.email ?? ''),
        _readOnlyField('Bio', _prefs['bio'] as String? ?? ''),
        _readOnlyField('Phone', _prefs['phone'] as String? ?? ''),
      ],
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.timestamp.copyWith(fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(value, style: AppText.name),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.panelTitle),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _toggleRow(IconData icon, String title, String subtitle, String prefKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.name),
                Text(subtitle, style: AppText.timestamp),
              ],
            ),
          ),
          Switch(
            value: _getBool(prefKey),
            activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
            activeThumbColor: AppColors.accent,
            onChanged: (v) => _setPref(prefKey, v),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPanel() {
    return _buildSection('Notifications', [
      _toggleRow(Icons.message_outlined, 'Message Notifications', 'Show alerts for new messages', 'msg_notif'),
      _toggleRow(Icons.volume_up_outlined, 'Sound', 'Play sound for messages', 'notif_sound'),
      _toggleRow(Icons.vibration_outlined, 'Vibrate', 'Vibrate on new messages', 'notif_vibrate'),
      _toggleRow(Icons.preview_outlined, 'Preview', 'Show message preview in notifications', 'notif_preview'),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.music_note_outlined, size: 20, color: AppColors.textHint),
        title: const Text('Ringtone', style: TextStyle(fontSize: 13)),
        trailing: const Text('Default', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        onTap: () {},
      ),
    ]);
  }

  Widget _buildChatsPanel() {
    final fontSize = _getDouble('font_size', 14);
    return _buildSection('Chat Settings', [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.text_fields, size: 20, color: AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font Size', style: TextStyle(fontSize: 13)),
                  Text('${fontSize.round()}px', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Slider(
                value: fontSize,
                min: 12, max: 20,
                divisions: 8,
                activeColor: AppColors.accent,
                overlayColor: WidgetStateProperty.all(AppColors.accent.withValues(alpha: 0.1)),
                thumbColor: AppColors.accent,
                label: '${fontSize.round()}px',
                onChanged: (v) => _setPref('font_size', v),
              ),
            ),
          ],
        ),
      ),
      _toggleRow(Icons.send_outlined, 'Enter Sends', 'Press Enter to send messages', 'enter_sends'),
      _toggleRow(Icons.download_outlined, 'Auto-Download', 'Auto-download media over WiFi', 'auto_download'),
      const SizedBox(height: 16),
      Text('Chat Wallpaper', style: AppText.timestamp.copyWith(fontSize: 11)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          _colorDot(const Color(0xFFF7F7F7), 'default'),
          _colorDot(const Color(0xFFE8F5EE), 'green'),
          _colorDot(const Color(0xFFFFF3E0), 'warm'),
          _colorDot(const Color(0xFFF3E5F5), 'purple'),
          _colorDot(const Color(0xFF1A2633), 'dark'),
        ],
      ),
    ]);
  }

  Widget _colorDot(Color color, String name) {
    final selected = (_prefs['wallpaper_color'] as String? ?? 'default') == name;
    return GestureDetector(
      onTap: () => _setPref('wallpaper_color', name),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.textPrimary : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Widget _buildCallsPanel() {
    return _buildSection('Call Settings', [
      _toggleRow(Icons.mic_off_outlined, 'Auto-mute on Join', 'Start calls muted', 'auto_mute'),
      _toggleRow(Icons.speaker_outlined, 'Speaker on Join', 'Auto-enable speaker', 'auto_speaker'),
      _toggleRow(Icons.videocam_outlined, 'Camera on Join', 'Auto-enable camera for video calls', 'auto_camera'),
    ]);
  }

  Widget _buildAccountPanel() {
    return _buildSection('Account', [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lock_outline, size: 20, color: AppColors.textHint),
        title: const Text('Change Password', style: TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {},
      ),
      const Divider(),
      _toggleRow(Icons.public_outlined, 'Private Account', 'Only approved contacts can message you', 'is_private'),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
          onPressed: () async {
            final nav = Navigator.of(context);
            await _settingsService.clearAll();
            await _auth.signOut();
            nav.pushReplacementNamed('/login');
          },
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: const Text('Delete Account'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () async {
            final nav = Navigator.of(context);
            final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Account'),
              content: const Text('This action is irreversible. All your data will be permanently deleted.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
              ],
            ));
            if (confirm == true) {
              await _auth.deleteAccount();
              nav.pushReplacementNamed('/login');
            }
          },
        ),
      ),
    ]);
  }

  Widget _buildAboutPanel() {
    return _buildSection('About', [
      _aboutRow('Version', '1.0.0'),
      _aboutRow('Privacy Policy', ''),
      _aboutRow('Terms of Service', ''),
    ]);
  }

  Widget _aboutRow(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppText.name),
      trailing: value.isNotEmpty ? Text(value, style: AppText.timestamp) : const Icon(Icons.chevron_right, size: 20),
      onTap: value.isEmpty ? () {} : null,
    );
  }
}

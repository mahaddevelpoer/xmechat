import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> _prefs = {};
  Map<String, dynamic>? _userProfile;
  bool _loading = true;
  String? _myId;

  final List<_SettingsItem> _navItems = [
    _SettingsItem(Icons.person_outline, 'Profile'),
    _SettingsItem(Icons.notifications_outlined, 'Notifications'),
    _SettingsItem(Icons.chat_bubble_outline, 'Chats'),
    _SettingsItem(Icons.call_outlined, 'Calls'),
    _SettingsItem(Icons.lock_outlined, 'Account'),
    _SettingsItem(Icons.info_outline, 'About'),
  ];

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};
    for (final k in keys) {
      data[k] = prefs.get(k);
    }
    if (_myId != null) {
      try {
        final profile = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', _myId!)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() { _userProfile = Map<String, dynamic>.from(profile); _prefs = data; _loading = false; });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _prefs = data; _loading = false; });
  }

  Future<void> _setPref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    setState(() => _prefs[key] = value);
  }

  bool _getBool(String key, [bool defaultValue = true]) => _prefs[key] as bool? ?? defaultValue;
  double _getDouble(String key, [double defaultValue = 14.0]) => _prefs[key] as double? ?? defaultValue;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppColors.surface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      Text('Settings', style: AppText.panelTitle),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (_userProfile != null)
                  InkWell(
                    onTap: () => setState(() => _selectedIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.accentLight,
                            child: Text(
                              (_userProfile!['name'] as String? ?? '?')[0].toUpperCase(),
                              style: AppText.name.copyWith(color: AppColors.accent),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_userProfile!['name'] as String? ?? 'User', style: AppText.name),
                                Text(_userProfile!['email'] as String? ?? '', style: AppText.timestamp),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final active = _selectedIndex == index;
                      return InkWell(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: active ? AppColors.accentLight : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon, size: 20, color: active ? AppColors.accent : AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Text(item.label, style: AppText.message.copyWith(color: active ? AppColors.accent : AppColors.textPrimary)),
                              const Spacer(),
                              Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    switch (_selectedIndex) {
      case 0: return _buildProfilePanel();
      case 1: return _buildNotificationsPanel();
      case 2: return _buildChatsPanel();
      case 3: return _buildCallsPanel();
      case 4: return _buildAccountPanel();
      case 5: return _buildAboutPanel();
      default: return const SizedBox();
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(title, style: AppText.sectionHeader),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }


  Widget _toggleRow(IconData icon, String label, String subtitle, String key) {
    final val = _getBool(key);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: AppText.timestamp.copyWith(fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _setPref(key, !val),
            child: Container(
              width: 42, height: 24,
              decoration: BoxDecoration(
                color: val ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: val ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePanel() {
    return _buildSection('Profile Info', [
      Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accentLight,
              child: Text((_userProfile?['name'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.accent)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userProfile?['name'] as String? ?? 'User', style: AppText.name.copyWith(fontSize: 15)),
                  Text(_userProfile?['email'] as String? ?? '', style: AppText.timestamp),
                ],
              ),
            ),
          ],
        ),
      ),
      _infoRow(Icons.edit_outlined, 'Display Name', _userProfile?['name'] as String? ?? ''),
      _infoRow(Icons.description_outlined, 'Bio', _userProfile?['bio'] as String? ?? ''),
      _infoRow(Icons.phone_outlined, 'Phone', _userProfile?['phone_info'] as String? ?? ''),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(_userProfile?['email'] as String? ?? '', style: AppText.message.copyWith(fontSize: 13))),
            Text('Read only', style: AppText.timestamp),
          ],
        ),
      ),
    ]);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                if (value.isNotEmpty) Text(value, style: AppText.timestamp.copyWith(fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPanel() {
    return Column(
      children: [
        _buildSection('Notifications', [
          _toggleRow(Icons.message_outlined, 'Message Notifications', 'Show notifications for new messages', 'notif_messages'),
          _toggleRow(Icons.call_outlined, 'Call Notifications', 'Show incoming call popup', 'notif_calls'),
          _toggleRow(Icons.notifications_active_outlined, 'Notification Sound', 'Play sound for notifications', 'notif_sound'),
          _toggleRow(Icons.visibility_outlined, 'Message Preview', 'Show message content in notification', 'notif_preview'),
        ]),
        _buildSection('Ringtone', [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.music_note_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Call Ringtone', style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Default Ringtone', style: AppText.timestamp.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildChatsPanel() {
    final fontSize = _getDouble('font_size');
    final fontSizeLabel = fontSize <= 13 ? 'Small' : fontSize <= 15 ? 'Medium' : fontSize <= 17 ? 'Large' : 'Extra Large';
    return _buildSection('Chat Settings', [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Text('Font Size', style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('$fontSizeLabel ($fontSize px)', style: AppText.timestamp.copyWith(fontSize: 11)),
              ],
            ),
            Slider(
              value: fontSize,
              min: 12,
              max: 20,
              divisions: 8,
              onChanged: (v) => _setPref('font_size', v),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text('Preview text at ${fontSize.toStringAsFixed(0)}px', style: AppText.message.copyWith(fontSize: fontSize)),
            ),
          ],
        ),
      ),
      _toggleRow(Icons.keyboard_return_outlined, 'Enter Key Sends', 'Press Enter to send, Shift+Enter for new line', 'enter_sends'),
      _toggleRow(Icons.download_outlined, 'Auto-download Media', 'Automatically download images and videos', 'auto_download'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Text('Chat Wallpaper', style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _colorDot(const Color(0xFFF7F7F7), 'default'),
                _colorDot(const Color(0xFFE8F0FE), 'blue'),
                _colorDot(const Color(0xFFE8F5E9), 'green'),
                _colorDot(const Color(0xFFFFF3E0), 'warm'),
                _colorDot(const Color(0xFFF3E5F5), 'purple'),
                _colorDot(const Color(0xFF1A2633), 'dark'),
              ],
            ),
          ],
        ),
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
      _toggleRow(Icons.videocam_off_outlined, 'Camera Off on Join', 'Start video calls with camera off', 'auto_camera_off'),
      _toggleRow(Icons.volume_up_outlined, 'Default Speaker', 'Use speaker for calls', 'default_speaker'),
    ]);
  }

  Widget _buildAccountPanel() {
    return Column(
      children: [
        _buildSection('Security', [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                const Icon(Icons.key_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Change Password', style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Update your account password', style: AppText.timestamp.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          _toggleRow(Icons.lock_outlined, 'Privacy', 'Who can find me', 'is_private'),
        ]),
        _buildSection('Account Actions', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Logout'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildAboutPanel() {
    return _buildSection('About XmeChat', [
      _simpleRow(Icons.smartphone_outlined, 'Version', '1.0.0 (Build 1)'),
      _simpleRow(Icons.description_outlined, 'Privacy Policy', '', arrow: true),
      _simpleRow(Icons.article_outlined, 'Terms of Service', '', arrow: true),
    ]);
  }

  Widget _simpleRow(IconData icon, String label, String value, {bool arrow = false}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.message.copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
          if (value.isNotEmpty) Text(value, style: AppText.timestamp),
          if (arrow) const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  const _SettingsItem(this.icon, this.label);
}

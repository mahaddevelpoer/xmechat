import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _chats = [];
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _loading = true;
  final String? _myId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('conversations')
          .select()
          .or('participant_1.eq.$_myId,participant_2.eq.$_myId')
          .order('last_message_at', ascending: false);
      setState(() {
        _chats = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      for (final chat in _chats) {
        final otherId = chat['participant_1'] == _myId ? chat['participant_2'] : chat['participant_1'];
        if (!_userCache.containsKey(otherId)) {
          _cacheUser(otherId);
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _cacheUser(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _userCache[userId] = Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats.where((c) {
      final otherId = c['participant_1'] == _myId ? c['participant_2'] : c['participant_1'];
      final user = _userCache[otherId];
      final name = (user?['name'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        return Row(
          children: [
            _buildIconRail(),
            if (!isNarrow) _buildChatList(),
            Expanded(
              child: _navIndex == 0
                  ? _buildMainPanel(isNarrow)
                  : _navIndex == 1
                      ? _buildStatusPlaceholder()
                      : _navIndex == 3
                          ? _buildSettingsPlaceholder()
                          : _buildMainPanel(isNarrow),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconRail() {
    return Container(
      width: 56,
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _navIcon(Icons.chat_bubble_outline, 'Chats', 0),
          const SizedBox(height: 4),
          _navIcon(Icons.circle_outlined, 'Status', 1),
          const Spacer(),
          _navIcon(Icons.settings_outlined, 'Settings', 3),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.accentLight,
            child: Text(
              _myId?.isNotEmpty == true ? 'M' : '?',
              style: AppText.timestamp.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, String tooltip, int index) {
    final active = _navIndex == index;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _navIndex = index),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? AppColors.accent : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Container(
      width: 320,
      color: AppColors.surface,
      child: Column(
        children: [
          _buildChatListHeader(),
          _buildSearchBar(),
          Expanded(child: _buildChatItems()),
        ],
      ),
    );
  }

  Widget _buildChatListHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('Chats', style: AppText.panelTitle),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _showNewChatDialog(),
            tooltip: 'New Chat',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 18),
            onSelected: (v) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new_group', child: Text('New Group', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'archived', child: Text('Archived Chats', style: TextStyle(fontSize: 13))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search, size: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildChatItems() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _filteredChats;
    if (items.isEmpty) {
      return Center(
        child: Text(_searchQuery.isNotEmpty ? 'No chats found' : 'No conversations yet', style: AppText.preview),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final chat = items[index];
        final otherId = chat['participant_1'] == _myId ? chat['participant_2'] : chat['participant_1'];
        final user = _userCache[otherId];
        final name = user?['name'] as String? ?? otherId ?? 'Unknown';
        final avatarUrl = user?['avatar_url'] as String? ?? '';
        final isOnline = user?['is_online'] as bool? ?? false;
        final lastMsg = chat['last_message'] as String? ?? '';
        final lastTime = chat['last_message_at'] as String? ?? '';

        return _buildChatItem(
          name: name,
          avatarUrl: avatarUrl,
          isOnline: isOnline,
          lastMessage: lastMsg,
          lastTime: _formatTime(lastTime),
          onTap: () => _openChat(chat['id'] as String, name, avatarUrl, otherId),
        );
      },
    );
  }

  Widget _buildChatItem({
    required String name,
    required String avatarUrl,
    required bool isOnline,
    required String lastMessage,
    required String lastTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accentLight,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent))
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: AppText.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(lastTime, style: AppText.timestamp),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(lastMessage, style: AppText.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel(bool isNarrow) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('XmeChat', style: AppText.heading.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Select a conversation to start chatting', style: AppText.preview),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPlaceholder() {
    return Container(
      color: AppColors.bg,
      child: const Center(child: Text('Status — Coming soon', style: TextStyle(color: AppColors.textHint))),
    );
  }

  Widget _buildSettingsPlaceholder() {
    return Container(
      color: AppColors.bg,
      child: const Center(child: Text('Settings — Coming soon', style: TextStyle(color: AppColors.textHint))),
    );
  }

  void _openChat(String chatId, String name, String avatarUrl, String otherUserId) {
    Navigator.pushNamed(context, '/chat/$chatId');
  }

  void _showNewChatDialog() {}

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

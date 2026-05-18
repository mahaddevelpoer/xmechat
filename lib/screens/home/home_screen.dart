import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import 'home_tabs/chats_tab.dart';
import 'home_tabs/status_tab.dart';
import 'home_tabs/calls_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _currentIndex = _tabController.index));
    _setOnline();
    _listenIncomingCalls();
  }

  Future<void> _setOnline() async {
    await ref.read(authServiceProvider).updateOnlineStatus(true);
  }

  void _listenIncomingCalls() {
    ref.listenManual(incomingCallProvider, (_, next) {
      final call = next.value;
      if (call != null && mounted) {
        context.push('/incoming-call', extra: call);
      }
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('XmeChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'new_group': context.push('/create-group'); break;
                case 'contacts': context.push('/contacts'); break;
                case 'settings': context.push('/settings'); break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'new_group', child: Text('New group')),
              PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ChatsTab(), StatusTab(), CallsTab()],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    if (_currentIndex == 0) {
      return FloatingActionButton(
        heroTag: 'chat_fab',
        onPressed: () => context.push('/contacts'),
        child: const Icon(Icons.chat),
      );
    }
    if (_currentIndex == 1) {
      return FloatingActionButton(
        heroTag: 'status_fab',
        onPressed: () => context.push('/create-status'),
        child: const Icon(Icons.edit),
      );
    }
    if (_currentIndex == 2) {
      return FloatingActionButton(
        heroTag: 'call_fab',
        onPressed: () => context.push('/contacts'),
        child: const Icon(Icons.add_call),
      );
    }
    return null;
  }
}

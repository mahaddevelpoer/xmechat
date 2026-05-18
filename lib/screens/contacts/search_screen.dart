import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search by name or email...',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctrl.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (users) {
          if (ref.watch(searchQueryProvider).isEmpty) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.search, size: 70, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('Search for users', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ]));
          }
          if (users.isEmpty) {
            return const Center(child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) {
              final user = users[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: UserAvatar(url: user.avatarUrl, name: user.name, isOnline: user.isOnline, radius: 26),
                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                subtitle: Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                onTap: () async {
                  final chatId = await ref.read(chatServiceProvider).getOrCreateChat(user.id);
                  if (!context.mounted) return;
                  context.push('/chat/$chatId', extra: {'user': user});
                },
              );
            },
          );
        },
      ),
    );
  }
}

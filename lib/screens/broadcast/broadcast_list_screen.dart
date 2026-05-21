import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

class BroadcastListScreen extends ConsumerWidget {
  const BroadcastListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(broadcastListsProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Broadcast Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/create-broadcast'),
          ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.broadcast_on_home,
                        size: 36, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 20),
                  const Text('No broadcast lists',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Create a list to send messages to multiple people',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-broadcast'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Broadcast List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lists.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) {
              final list = lists[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryGreen,
                  child: Text(
                    list.name.isNotEmpty ? list.name[0].toUpperCase() : 'B',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(list.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${list.members.length} recipients',
                    style: const TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/broadcast-chat/${list.id}',
                    extra: list),
              );
            },
          );
        },
      ),
    );
  }
}

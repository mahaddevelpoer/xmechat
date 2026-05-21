import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/user_avatar.dart';

class StatusTab extends ConsumerWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(statusesProvider);
    final myStatusesAsync = ref.watch(myStatusesProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final myId = ref.read(authServiceProvider).currentUserId;

    return statusesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (statuses) {
        final myStatuses = myStatusesAsync.value ?? [];
        // Group statuses by user
        final Map<String, List<StatusModel>> grouped = {};
        for (final s in statuses) {
          if (s.userId == myId) continue; // my statuses shown separately
          grouped[s.userId] = (grouped[s.userId] ?? [])..add(s);
        }
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(statusesProvider.future),
              ref.refresh(myStatusesProvider.future),
            ]);
          },
          child: ListView(
            children: [
              // My Status
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Stack(
                  children: [
                    UserAvatar(
                      url: me?.avatarUrl,
                      name: me?.name ?? 'Me',
                      radius: 26,
                      borderColor: myStatuses.isNotEmpty
                          ? AppColors.accentGreen
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                title: const Text(
                  'My Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  myStatuses.isEmpty
                      ? 'Tap to add status update'
                      : '${myStatuses.length} update(s)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  if (myStatuses.isEmpty) {
                    context.push('/create-status');
                  } else {
                    context.push(
                      '/status/$myId',
                      extra: {'statuses': myStatuses},
                    );
                  }
                },
              ),
              if (grouped.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'RECENT UPDATES',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...grouped.entries.map((entry) {
                  final userStatuses = entry.value;
                  final user = userStatuses.first.user;
                  final allViewed = userStatuses.every((s) => s.viewedByMe);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: UserAvatar(
                      url: user?.avatarUrl,
                      name: user?.name ?? '?',
                      radius: 26,
                      borderColor: allViewed
                          ? AppColors.textHint
                          : AppColors.accentGreen,
                    ),
                    title: Text(
                      user?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${userStatuses.length} update(s)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => context.push(
                      '/status/${entry.key}',
                      extra: {'statuses': userStatuses},
                    ),
                  );
                }),
              ] else
                const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

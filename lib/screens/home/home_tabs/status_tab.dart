import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/user_avatar.dart';

class StatusTab extends ConsumerWidget {
  const StatusTab({super.key});

  int _columnCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 3;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildGlassCard({
    required Widget child,
    bool expired = false,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expired ? AppColors.outline : AppColors.glassBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: AppColors.glassBg, child: child),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moments',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hanken Grotesk',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ephemeral updates from your crew.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewUpdateButton(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.secondaryContainer,
                AppColors.primaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/create-status'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppColors.onSecondary),
                    SizedBox(width: 8),
                    Text(
                      'New Update',
                      style: TextStyle(
                        color: AppColors.onSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        onPressed: () => context.push('/create-status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.secondaryContainer,
                AppColors.primaryContainer,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryContainer,
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: AppColors.onSecondary),
        ),
      ),
    );
  }

  Widget _buildAddStatusCard(
    BuildContext context,
    WidgetRef ref,
    UserModel? me,
    int myStatusesCount,
    String myId,
  ) {
    return GestureDetector(
      onTap: () {
        if (myStatusesCount == 0) {
          context.push('/create-status');
        } else {
          final myStatuses = ref.read(myStatusesProvider).valueOrNull ?? [];
          context.push('/status/$myId', extra: {'statuses': myStatuses});
        }
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: AppColors.glassBg,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: AppColors.outline,
                  radius: 16,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary.withAlpha(51),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppColors.secondary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        myStatusesCount == 0 ? 'Add Status' : 'My Status',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        myStatusesCount == 0
                            ? 'Share a moment'
                            : '$myStatusesCount update(s)',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
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
    );
  }

  Widget _buildImageStatusCard(
    StatusModel status,
    List<StatusModel> userStatuses,
    String userId,
    BuildContext context,
  ) {
    final user = status.user;
    final expired = status.isExpired;

    Widget card = SizedBox(
      height: 280,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                status.contentUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceContainerHigh,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.surfaceContainerHigh,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xB3000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withAlpha(128),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceContainerHighest,
                backgroundImage: user?.avatarUrl.isNotEmpty == true
                    ? NetworkImage(user!.avatarUrl)
                    : null,
                child: user?.avatarUrl.isEmpty != false
                    ? Text(
                        user?.name.isNotEmpty == true
                            ? user!.name.trim()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    status.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _timeAgo(status.createdAt),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (expired) {
      card = Opacity(opacity: 0.6, child: card);
    }

    return GestureDetector(
      onTap: () => context.push(
        '/status/$userId',
        extra: {'statuses': userStatuses},
      ),
      child: card,
    );
  }

  Widget _buildTextStatusCard(
    StatusModel status,
    List<StatusModel> userStatuses,
    String userId,
    BuildContext context,
  ) {
    final user = status.user;
    final expired = status.isExpired;

    Widget card = _buildGlassCard(
      expired: expired,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  url: user?.avatarUrl,
                  name: user?.name ?? '?',
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user?.name ?? 'Unknown',
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _timeAgo(status.createdAt),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              status.text.isNotEmpty ? status.text : '(no text)',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (expired) {
      card = Opacity(opacity: 0.6, child: card);
    }

    return GestureDetector(
      onTap: () => context.push(
        '/status/$userId',
        extra: {'statuses': userStatuses},
      ),
      child: card,
    );
  }

  Widget _buildMasonryLayout(List<Widget> cards, int columnCount) {
    final cols = List.generate(columnCount, (_) => <Widget>[]);
    for (int i = 0; i < cards.length; i++) {
      cols[i % columnCount].add(cards[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(columnCount, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
            child: Column(
              children: cols[i]
                  .map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: w,
                      ))
                  .toList(),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.all_inclusive_outlined,
            size: 64,
            color: AppColors.onSurfaceVariant.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'No statuses yet',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a moment',
            style: TextStyle(
              color: AppColors.onSurfaceVariant.withAlpha(179),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(statusesProvider);
    final myStatusesAsync = ref.watch(myStatusesProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final myId = ref.read(authServiceProvider).currentUserId;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return statusesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (statuses) {
        final myStatuses = myStatusesAsync.value ?? [];
        final Map<String, List<StatusModel>> grouped = {};
        for (final s in statuses) {
          if (s.userId == myId) continue;
          grouped.putIfAbsent(s.userId, () => []);
          grouped[s.userId]!.add(s);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.refresh(statusesProvider.future),
                ref.refresh(myStatusesProvider.future),
              ]);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = _columnCount(constraints.maxWidth);
                final cards = <Widget>[];

                cards.add(_buildAddStatusCard(
                    context, ref, me, myStatuses.length, myId));

                for (final entry in grouped.entries) {
                  for (final status in entry.value) {
                    if ((status.type == 'image' ||
                            status.type == 'video') &&
                        status.contentUrl.isNotEmpty) {
                      cards.add(_buildImageStatusCard(
                          status, entry.value, entry.key, context));
                    } else {
                      cards.add(_buildTextStatusCard(
                          status, entry.value, entry.key, context));
                    }
                  }
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    if (!isMobile)
                      SliverToBoxAdapter(
                          child: _buildNewUpdateButton(context)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (cards.length == 1)
                            _buildEmptyState()
                          else
                            _buildMasonryLayout(cards, cols),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: isMobile ? _buildFAB(context) : null,
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    const dash = 8.0;
    const gap = 5.0;

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length) as double;
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

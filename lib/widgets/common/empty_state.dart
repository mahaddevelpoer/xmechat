import 'package:flutter/material.dart';
import '../../theme.dart';

/// Generic empty state with icon, title, and optional subtitle + action button.
/// Used in every StreamBuilder/FutureBuilder empty-data state.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppText.name.copyWith(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppText.bodyGrey,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minimal empty chat panel — shown in Panel C when no chat is selected.
class NoChatSelected extends StatelessWidget {
  const NoChatSelected({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text('XmeChat Desktop', style: AppText.title.copyWith(color: AppColors.textGrey)),
          const SizedBox(height: 6),
          Text('Select a chat to start messaging', style: AppText.bodyGrey),
        ],
      ),
    );
  }
}

/// Error state shown when a stream or future fails.
class ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const ErrorState({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Something went wrong', style: AppText.name.copyWith(color: AppColors.textGrey)),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error.toString(),
                style: AppText.caption,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

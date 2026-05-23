import 'package:flutter/material.dart';
import '../../theme.dart';

/// Centered circular progress indicator with optional label.
/// Used in every StreamBuilder/FutureBuilder loading state.
class LoadingWidget extends StatelessWidget {
  final String? label;

  const LoadingWidget({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: AppText.bodyGrey),
          ],
        ],
      ),
    );
  }
}

/// A small inline spinner — used inside buttons or list items.
class InlineSpinner extends StatelessWidget {
  final double size;
  final Color color;

  const InlineSpinner({
    super.key,
    this.size = 16,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: color,
      ),
    );
  }
}

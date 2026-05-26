import 'package:flutter/material.dart';
import '../../theme.dart';

class ReplyPreview extends StatelessWidget {
  final String senderName;
  final String preview;
  final VoidCallback? onCancel;

  const ReplyPreview({
    super.key,
    required this.senderName,
    required this.preview,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(senderName, style: AppText.label.copyWith(color: AppColors.accent)),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: AppText.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

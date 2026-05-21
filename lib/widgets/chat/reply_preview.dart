import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';

class ReplyPreview extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onClose;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // In a real app, you might look up the sender's actual name from their ID
    // if you have it cached. For now, we will display a fallback name or the senderId.
    final senderName = message.senderUser?.name ?? 'Someone';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppColors.primaryGreen, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.text.isNotEmpty ? message.text : 'Media message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textHint),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/models.dart';

/// Reply preview banner shown between the message list and input bar.
/// Displays the message being replied to with an accent left border.
class ReplyPreview extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onCancel;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.onCancel,
  });

  String get _previewText {
    switch (message.type) {
      case MessageType.audio:   return '🎵 Voice note';
      case MessageType.image:   return '📷 Photo';
      case MessageType.video:   return '🎥 Video';
      case MessageType.document: return '📄 ${message.fileName.isNotEmpty ? message.fileName : 'Document'}';
      case MessageType.location: return '📍 Location';
      case MessageType.contact:  return '👤 ${message.contactName}';
      default:
        return message.text.isNotEmpty ? message.text : '(Message)';
    }
  }

  IconData get _typeIcon {
    switch (message.type) {
      case MessageType.audio:    return Icons.mic;
      case MessageType.image:    return Icons.image_outlined;
      case MessageType.video:    return Icons.videocam_outlined;
      case MessageType.document: return Icons.insert_drive_file_outlined;
      case MessageType.location: return Icons.location_on_outlined;
      case MessageType.contact:  return Icons.person_outline;
      default:                   return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Accent left bar
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Media type icon (for non-text)
          if (message.type != MessageType.text) ...[
            Icon(_typeIcon, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
          ],

          // Preview text + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to message',
                  style: AppText.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewText,
                  style: AppText.bodyGrey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textGrey),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Compact reply preview shown *inside* a message bubble.
/// Displays what the message is replying to.
class InlineBubbleReply extends StatelessWidget {
  final String previewText;
  final bool isSent;

  const InlineBubbleReply({
    super.key,
    required this.previewText,
    required this.isSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSent
            ? Colors.black.withOpacity(0.07)
            : AppColors.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Text(
        previewText,
        style: AppText.caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

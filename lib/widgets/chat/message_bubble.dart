import 'package:flutter/material.dart';
import '../../theme.dart';

class MessageBubble extends StatelessWidget {
  final bool isSent;
  final String text;
  final String time;
  final String? imageUrl;
  final String? fileName;
  final int? fileSize;
  final int? durationSeconds;
  final bool isVoiceNote;
  final bool isDocument;
  final String statusIcon;
  final Color? statusColor;
  final Widget? replyPreview;
  final List<String> reactions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? voiceNoteWidget;

  const MessageBubble({
    super.key,
    required this.isSent,
    required this.text,
    required this.time,
    this.imageUrl,
    this.fileName,
    this.fileSize,
    this.durationSeconds,
    this.isVoiceNote = false,
    this.isDocument = false,
    this.statusIcon = '',
    this.statusColor,
    this.replyPreview,
    this.reactions = const [],
    this.onTap,
    this.onLongPress,
    this.voiceNoteWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyPreview != null) replyPreview!,
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.58),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSent ? AppColors.sentBubble : AppColors.recvBubble,
                borderRadius: isSent
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(3),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                border: isSent ? null : Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty) _buildImage(),
                  if (isVoiceNote && voiceNoteWidget != null) voiceNoteWidget!,
                  if (isDocument) _buildDocument(),
                  if (text.isNotEmpty) Text(text, style: AppText.message),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time, style: AppText.timestamp),
                      if (statusIcon.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.check, size: 12, color: statusColor ?? AppText.timestamp.color),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: reactions.map((r) {
                  return Container(
                    margin: const EdgeInsets.only(right: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.recvBubble,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(r, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: 200,
        height: 160,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 200,
            height: 160,
            color: AppColors.border.withValues(alpha: 0.2),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          width: 200,
          height: 160,
          color: AppColors.border.withValues(alpha: 0.2),
          child: const Center(child: Icon(Icons.broken_image, color: AppColors.textHint)),
        ),
      ),
    );
  }

  Widget _buildDocument() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file_outlined, size: 24, color: AppColors.accent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName ?? 'Document', style: AppText.name.copyWith(fontSize: 12)),
            if (fileSize != null)
              Text(_formatSize(fileSize!), style: AppText.timestamp),
          ],
        ),
        const SizedBox(width: 8),
        const Icon(Icons.download, size: 16, color: AppColors.accent),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/models.dart';
import 'voice_note_player.dart';
import 'reply_preview.dart';
import '../common/user_avatar.dart';

/// Full standalone message bubble.
/// Handles all message types: text, image, video, audio,
/// document, location, contact, deleted.
/// Used in PrivateChatScreen and GroupChatScreen.
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isSent;
  final String? senderName;      // shown in group chats
  final String? senderAvatarUrl; // shown in group chats / received
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onStar;
  final bool showSenderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.senderName,
    this.senderAvatarUrl,
    this.onReply,
    this.onDelete,
    this.onCopy,
    this.onForward,
    this.onStar,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.deletedForEveryone) {
      return _DeletedBubble(isSent: isSent);
    }

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for received messages
            if (!isSent) ...[
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: UserAvatar(
                  imageUrl: senderAvatarUrl,
                  name: senderName ?? '?',
                  size: 28,
                ),
              ),
            ],

            // The bubble itself
            GestureDetector(
              onSecondaryTapDown: (d) =>
                  _showContextMenu(context, d.globalPosition),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration:
                      isSent ? AppDeco.sentBubble : AppDeco.recvBubble,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sender name (group chats)
                      if (showSenderName && senderName != null && !isSent)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            senderName!,
                            style: AppText.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // Forwarded label
                      if (message.isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.forward,
                                  size: 11, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text('Forwarded',
                                  style: AppText.caption.copyWith(
                                      fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),

                      // Reply preview inside bubble
                      if (message.replyPreview.isNotEmpty)
                        InlineBubbleReply(
                          previewText: message.replyPreview,
                          isSent: isSent,
                        ),

                      // Message content by type
                      _buildContent(context),

                      // Timestamp + status row
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (message.isStarred)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.star,
                                  size: 11, color: AppColors.accent),
                            ),
                          Text(
                            DateFormat('h:mm a').format(message.createdAt),
                            style: AppText.timestamp,
                          ),
                          if (isSent) ...[
                            const SizedBox(width: 4),
                            _TickIcon(status: message.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Spacer for sent messages (no avatar)
            if (isSent) const SizedBox(width: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(message.text, style: AppText.body);

      case MessageType.audio:
        return VoiceNotePlayer(
          audioUrl: message.mediaUrl,
          durationSeconds: message.duration,
          senderAvatarUrl: senderAvatarUrl,
          senderName: senderName ?? '?',
          isSent: isSent,
        );

      case MessageType.image:
        return _ImageBubble(url: message.mediaUrl);

      case MessageType.video:
        return _VideoBubble(url: message.mediaUrl);

      case MessageType.document:
        return _DocumentBubble(
          fileName: message.fileName,
          fileSize: message.fileSize,
          url: message.mediaUrl,
        );

      case MessageType.location:
        return _LocationBubble(
          lat: message.latitude ?? 0,
          lng: message.longitude ?? 0,
          name: message.locationName,
        );

      case MessageType.contact:
        return _ContactBubble(
          name: message.contactName,
          phone: message.contactPhone,
        );

      case MessageType.deleted:
        return Text(
          'This message was deleted',
          style: AppText.bodyGrey.copyWith(fontStyle: FontStyle.italic),
        );

      default:
        return message.text.isNotEmpty
            ? Text(message.text, style: AppText.body)
            : const SizedBox.shrink();
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      items: [
        if (onReply != null)
          PopupMenuItem(
            onTap: onReply,
            child: const _MenuRow(Icons.reply, 'Reply'),
          ),
        if (message.type == MessageType.text && onCopy != null)
          PopupMenuItem(
            onTap: onCopy,
            child: const _MenuRow(Icons.copy, 'Copy'),
          ),
        if (onForward != null)
          PopupMenuItem(
            onTap: onForward,
            child: const _MenuRow(Icons.forward, 'Forward'),
          ),
        if (onStar != null)
          PopupMenuItem(
            onTap: onStar,
            child: _MenuRow(
              message.isStarred ? Icons.star_border : Icons.star,
              message.isStarred ? 'Unstar' : 'Star',
            ),
          ),
        if (onDelete != null)
          PopupMenuItem(
            onTap: onDelete,
            child: const _MenuRow(Icons.delete_outline, 'Delete',
                color: AppColors.danger),
          ),
      ],
    );
  }
}

// ─── Content sub-widgets ─────────────────────────────

class _ImageBubble extends StatelessWidget {
  final String url;
  const _ImageBubble({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 220,
        height: 180,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                width: 220,
                height: 180,
                color: AppColors.border,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => Container(
          width: 220,
          height: 60,
          color: AppColors.border,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined,
                  size: 20, color: AppColors.textHint),
              SizedBox(width: 6),
              Text('Image unavailable',
                  style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 12,
                      color: AppColors.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoBubble extends StatelessWidget {
  final String url;
  const _VideoBubble({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded,
            size: 48, color: AppColors.white),
      ),
    );
  }
}

class _DocumentBubble extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final String url;
  const _DocumentBubble(
      {required this.fileName, required this.fileSize, required this.url});

  String get _sizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.insert_drive_file_outlined,
              color: AppColors.accent, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                fileName.isNotEmpty ? fileName : 'Document',
                style: AppText.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(_sizeLabel, style: AppText.caption),
          ],
        ),
        const SizedBox(width: 8),
        const Icon(Icons.download_outlined,
            size: 18, color: AppColors.accent),
      ],
    );
  }
}

class _LocationBubble extends StatelessWidget {
  final double lat;
  final double lng;
  final String name;
  const _LocationBubble(
      {required this.lat, required this.lng, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.danger, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Location',
                  style: AppText.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactBubble extends StatelessWidget {
  final String name;
  final String phone;
  const _ContactBubble({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentLight,
            child: Icon(Icons.person, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.name, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(phone, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isSent;
  const _DeletedBubble({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              'This message was deleted',
              style:
                  AppText.bodyGrey.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tick icons ──────────────────────────────────────

class _TickIcon extends StatelessWidget {
  final MessageStatus status;
  const _TickIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.textHint),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: AppColors.textHint);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 13,
            color: AppColors.textHint);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 13,
            color: AppColors.accent);
    }
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuRow(this.icon, this.label,
      {this.color = AppColors.textDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: AppText.body.copyWith(color: color)),
      ],
    );
  }
}

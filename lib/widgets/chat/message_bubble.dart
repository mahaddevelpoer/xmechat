import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../core/constants/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String otherUserName;
  final VoidCallback? onLongPress;
  final void Function(MessageModel)? onReply;
  final VoidCallback? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    this.onLongPress,
    this.onReply,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? AppColors.sentBubble : AppColors.receivedBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(8),
                  topRight: const Radius.circular(8),
                  bottomLeft: isMe ? const Radius.circular(8) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? 'You' : otherUserName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (message.replyPreview.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.replyPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  _MessageContent(message: message),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('h:mm a')
                            .format(message.createdAt)
                            .toLowerCase(),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.sending
                              ? Icons.access_time
                              : message.status == MessageStatus.read
                                  ? Icons.done_all
                                  : message.status == MessageStatus.delivered
                                      ? Icons.done_all
                                      : Icons.done,
                          size: 14,
                          color: message.status == MessageStatus.read
                              ? Colors.blue
                              : AppColors.textHint,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (message.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
                child: _ReactionsPill(reactions: message.reactions),
              ),
          ],
        ),
      ),
    );

    if (onReply == null) return bubble;

    // Swipe right to reply (WhatsApp style).
    return Dismissible(
      key: ValueKey('msg-${message.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        onReply?.call(message);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.reply, color: AppColors.primaryGreen),
      ),
      child: bubble,
    );
  }
}

class _ReactionsPill extends StatelessWidget {
  final List<ReactionModel> reactions;
  const _ReactionsPill({required this.reactions});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            Text(entries[i].key, style: const TextStyle(fontSize: 14)),
            if (entries[i].value > 1)
              Padding(
                padding: const EdgeInsets.only(left: 2, right: 6),
                child: Text(
                  '${entries[i].value}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              )
            else if (i != entries.length - 1)
              const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final MessageModel message;
  const _MessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
      case MessageType.viewOnce:
        if (message.isViewOnce && message.viewOnceOpened) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'View once photo (opened)',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        if (message.mediaUrl.isEmpty) {
          return const Text(
            '📷 Photo',
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: message.mediaUrl,
                    width: 240,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 240,
                      height: 180,
                      color: Colors.black.withAlpha(20),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 240,
                      height: 180,
                      color: Colors.black.withAlpha(20),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textHint),
                      ),
                    ),
                  ),
                  if (message.isViewOnce)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'View once',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (message.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.text,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ]
          ],
        );

      case MessageType.document:
        return _DocumentBubble(message: message);

      case MessageType.audio:
        return _AudioBubble(url: message.mediaUrl);

      case MessageType.location:
        final label = message.locationName.isNotEmpty ? message.locationName : 'Location';
        return Text('📍 $label',
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary));

      case MessageType.contact:
        final name = message.contactName.isNotEmpty ? message.contactName : 'Contact';
        return Text('👤 $name',
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary));

      case MessageType.video:
        return _VideoBubble(message: message);

      case MessageType.gif:
        return const Text(
          'GIF',
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        );

      case MessageType.poll:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.poll_outlined, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Poll', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
        );

      case MessageType.sticker:
        return const Text(
          'Sticker',
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        );

      case MessageType.deleted:
        return const Text(
          '🚫 Deleted message',
          style: TextStyle(fontSize: 14, color: AppColors.textHint, fontStyle: FontStyle.italic),
        );

      case MessageType.text:
        return Text(
          message.text,
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        );
    }
  }
}

class _DocumentBubble extends StatelessWidget {
  final MessageModel message;
  const _DocumentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final name = message.fileName.isNotEmpty ? message.fileName : 'Document';
    return InkWell(
      onTap: message.mediaUrl.isEmpty
          ? null
          : () async {
              final uri = Uri.tryParse(message.mediaUrl);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.textSecondary),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  final String url;
  const _AudioBubble({required this.url});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _VideoBubble extends StatelessWidget {
  final MessageModel message;
  const _VideoBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isViewOnce && message.viewOnceOpened) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'View once video (opened)',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_outline, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          const Text('Video', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          if (message.isViewOnce) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'View once',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<Duration>? _posSub;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _durSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  Future<void> _togglePlay() async {
    if (widget.url.isEmpty) return;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.idle) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(widget.url);
        await _player.setSpeed(_speed);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
    await _player.play();
  }

  Future<void> _cycleSpeed() async {
    final next = _speed == 1.0 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0);
    setState(() => _speed = next);
    await _player.setSpeed(next);
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.playing;
    final maxMs = _duration.inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs == 0 ? 0 : maxMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          SizedBox(
            width: 140,
            child: Slider(
              value: posMs.toDouble(),
              max: maxMs.toDouble() == 0 ? 1 : maxMs.toDouble(),
              onChanged: (v) async {
                await _player.seek(Duration(milliseconds: v.round()));
              },
            ),
          ),
          TextButton(
            onPressed: _cycleSpeed,
            child: Text('${_speed}x',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

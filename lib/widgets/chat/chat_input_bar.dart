import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../theme.dart';
import '../../models/models.dart';

/// Callback signatures
typedef OnSendText   = void Function(String text);
typedef OnSendVoice  = void Function(Uint8List bytes, int durationMs, String ext);
typedef OnSendFile   = void Function(Uint8List bytes, String fileName, MessageType type);

/// Full input bar widget.
/// Handles text input, voice recording, and file attachment.
/// Mic icon → hold to record, release to send.
/// Send icon → send text.
/// Shows recording UI while recording.
class ChatInputBar extends StatefulWidget {
  final OnSendText  onSendText;
  final OnSendVoice onSendVoice;
  final OnSendFile  onSendFile;
  final MessageModel? replyTo;
  final VoidCallback? onCancelReply;
  final bool enterToSend;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.onSendFile,
    this.replyTo,
    this.onCancelReply,
    this.enterToSend = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _textCtrl  = TextEditingController();
  final _focusNode = FocusNode();
  final _recorder  = AudioRecorder();

  bool _isRecording  = false;
  bool _isPaused     = false;
  bool _hasMicPerm   = false;
  bool _showEmoji    = false;
  Timer? _recordTimer;
  int   _recordSecs  = 0;
  int   _pauseOffset = 0;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
    _checkMicPerm();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkMicPerm() async {
    final has = await _recorder.hasPermission();
    if (mounted) setState(() => _hasMicPerm = has);
  }

  bool get _hasText => _textCtrl.text.trim().isNotEmpty;

  // ── Send text ───────────────────────────────────────
  void _sendText() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    widget.onSendText(t);
  }

  // ── Attach file ─────────────────────────────────────
  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;

    MessageType type = MessageType.document;
    final ext = (f.extension ?? '').toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      type = MessageType.image;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      type = MessageType.video;
    } else if (['mp3', 'm4a', 'aac', 'wav', 'ogg'].contains(ext)) {
      type = MessageType.audio;
    }

    widget.onSendFile(f.bytes!, f.name, type);
  }

  // ── Voice recording ─────────────────────────────────
  Future<void> _startRecording() async {
    if (!_hasMicPerm) {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Microphone permission denied.')),
          );
        }
        return;
      }
      setState(() => _hasMicPerm = true);
    }

    try {
      final dir  = await getTemporaryDirectory();
      _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
        ),
        path: _recordPath!,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordSecs  = 0;
        _pauseOffset = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSecs++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _pauseResume() async {
    if (_isPaused) {
      await _recorder.resume();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSecs++);
      });
    } else {
      await _recorder.pause();
      _recordTimer?.cancel();
    }
    if (mounted) setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopAndSend() async {
    _recordTimer?.cancel();
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();
      setState(() { _isRecording = false; _isPaused = false; });

      if (path == null) return;
      final file  = File(path);
      final bytes = await file.readAsBytes();
      await file.delete().catchError((_) => file as FileSystemEntity);

      if (bytes.isEmpty) return;
      widget.onSendVoice(bytes, _recordSecs * 1000, 'wav');
    } catch (e) {
      setState(() { _isRecording = false; _isPaused = false; });
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() { _isRecording = false; _isPaused = false; _recordSecs = 0; });
  }

  void _onEmojiSelected(emoji_picker.Emoji emoji) {
    final pos = _textCtrl.selection.baseOffset;
    final text = _textCtrl.text;
    if (pos < 0 || pos > text.length) {
      _textCtrl.text = text + emoji.emoji;
    } else {
      _textCtrl.text = text.substring(0, pos) + emoji.emoji + text.substring(pos);
      _textCtrl.selection = TextSelection.collapsed(offset: pos + emoji.emoji.length);
    }
  }

  String _formatSecs(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) _focusNode.unfocus();
      else _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        if (_isRecording)
          _RecordingBar(
            seconds: _recordSecs,
            isPaused: _isPaused,
            onCancel: _cancelRecording,
            onSend: _stopAndSend,
            onPauseResume: _pauseResume,
            formatSecs: _formatSecs,
          )
        else
          _NormalBar(
            textCtrl: _textCtrl,
            focusNode: _focusNode,
            hasText: _hasText,
            replyTo: widget.replyTo,
            onCancelReply: widget.onCancelReply,
            onAttach: _attachFile,
            onSend: _sendText,
            onStartRecording: _startRecording,
            onToggleEmoji: _toggleEmoji,
            enterToSend: widget.enterToSend,
          ),
        if (_showEmoji)
          SizedBox(
            height: 250,
            child: emoji_picker.EmojiPicker(
              onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji),
              config: emoji_picker.Config(
                emojiViewConfig: emoji_picker.EmojiViewConfig(),
                categoryViewConfig: emoji_picker.CategoryViewConfig(),
                skinToneConfig: emoji_picker.SkinToneConfig(),
                bottomActionBarConfig: const emoji_picker.BottomActionBarConfig(),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Normal input bar ────────────────────────────────

class _NormalBar extends StatelessWidget {
  final TextEditingController textCtrl;
  final FocusNode focusNode;
  final bool hasText;
  final MessageModel? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final VoidCallback onToggleEmoji;
  final bool enterToSend;

  const _NormalBar({
    required this.textCtrl,
    required this.focusNode,
    required this.hasText,
    required this.replyTo,
    required this.onCancelReply,
    required this.onAttach,
    required this.onSend,
    required this.onStartRecording,
    required this.onToggleEmoji,
    required this.enterToSend,
  });

  String _replyPreview(MessageModel m) {
    switch (m.type) {
      case MessageType.audio:   return '🎵 Voice note';
      case MessageType.image:   return '📷 Photo';
      case MessageType.video:   return '🎥 Video';
      case MessageType.document: return '📄 Document';
      default: return m.text.isNotEmpty ? m.text : '(Message)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview inside input area
        if (replyTo != null)
          Container(
            color: AppColors.accentLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              children: [
                Container(
                    width: 3, height: 32, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Replying',
                          style: AppText.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                      Text(_replyPreview(replyTo!),
                          style: AppText.bodyGrey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onCancelReply != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onCancelReply,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
          ),

        // Input row
        Container(
          constraints:
              const BoxConstraints(minHeight: AppSizes.inputBarHeight),
          color: AppColors.panel,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji button
              Tooltip(
                message: 'Emoji',
                child: IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: AppColors.textGrey,
                  onPressed: onToggleEmoji,
                ),
              ),

              // Attach file
              Tooltip(
                message: 'Attach file',
                child: IconButton(
                  icon: const Icon(Icons.attach_file_outlined),
                  color: AppColors.textGrey,
                  onPressed: onAttach,
                ),
              ),

              // Text field
              Expanded(
                child: TextField(
                  controller: textCtrl,
                  focusNode: focusNode,
                  maxLines: 6,
                  minLines: 1,
                  style: AppText.body,
                  textInputAction: enterToSend
                      ? TextInputAction.send
                      : TextInputAction.newline,
                  onSubmitted: enterToSend ? (_) => onSend() : null,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: AppText.hint,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.bg,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Send / Mic button
              if (hasText)
                Tooltip(
                  message: 'Send',
                  child: InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: AppColors.white, size: 18),
                    ),
                  ),
                )
              else
                Tooltip(
                  message: 'Hold to record, slide up to cancel',
                  child: GestureDetector(
                    onLongPressStart: (_) => onStartRecording(),
                    onLongPressEnd: (_) {
                      // Release to stop recording (send)
                    },
                    child: IconButton(
                      icon: const Icon(Icons.mic_outlined),
                      color: AppColors.textGrey,
                      onPressed: onStartRecording,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Recording bar ────────────────────────────────────

class _RecordingBar extends StatelessWidget {
  final int seconds;
  final bool isPaused;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onPauseResume;
  final String Function(int) formatSecs;

  const _RecordingBar({
    required this.seconds,
    required this.isPaused,
    required this.onCancel,
    required this.onSend,
    required this.onPauseResume,
    required this.formatSecs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.inputBarHeight,
      color: AppColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Cancel (trash bin)
          Tooltip(
            message: 'Delete recording',
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 22, color: AppColors.danger),
              onPressed: onCancel,
            ),
          ),
          const SizedBox(width: 4),
          // Pause / Resume
          if (!isPaused) _PulsingDot() else const SizedBox(width: 10),
          const SizedBox(width: 10),
          Text(
            isPaused ? 'Paused ${formatSecs(seconds)}' : 'Recording... ${formatSecs(seconds)}',
            style: AppText.body.copyWith(color: AppColors.danger),
          ),
          const Spacer(),
          // Pause / Resume button
          InkWell(
            onTap: onPauseResume,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPaused ? AppColors.accent : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: isPaused ? AppColors.white : AppColors.textDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send recording
          InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppColors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

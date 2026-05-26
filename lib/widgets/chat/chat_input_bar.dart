import 'package:flutter/material.dart';
import '../../theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController textController;
  final bool isLoading;
  final bool isRecording;
  final String recordingDuration;
  final VoidCallback onSend;
  final VoidCallback onMicLongPressStart;
  final VoidCallback onMicLongPressEnd;
  final VoidCallback onCancelRecording;
  final VoidCallback? onEmojiTap;
  final VoidCallback? onAttachTap;
  final Widget? replyPreview;
  final bool showSend;

  const ChatInputBar({
    super.key,
    required this.textController,
    this.isLoading = false,
    this.isRecording = false,
    this.recordingDuration = '0:00',
    required this.onSend,
    required this.onMicLongPressStart,
    required this.onMicLongPressEnd,
    required this.onCancelRecording,
    this.onEmojiTap,
    this.onAttachTap,
    this.replyPreview,
    this.showSend = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _showEmojiPicker = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyPreview != null) widget.replyPreview!,
        if (_showEmojiPicker)
          Container(
            height: 280,
            color: AppColors.surface,
            child: const Center(child: Text('Emoji picker', style: TextStyle(color: AppColors.textHint))),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: widget.isRecording
              ? _buildRecordingUI()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, size: 20),
                      onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                      tooltip: 'Emoji',
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file_outlined, size: 20),
                      onPressed: widget.onAttachTap,
                      tooltip: 'Attach',
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.textController,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: AppText.message,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: widget.showSend
                          ? _buildSendButton()
                          : GestureDetector(
                              onLongPressStart: (_) => widget.onMicLongPressStart(),
                              onLongPressEnd: (_) => widget.onMicLongPressEnd(),
                              child: Container(
                                key: const ValueKey('mic'),
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                child: const Icon(Icons.mic, color: Colors.white, size: 18),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    return Row(
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            if (details.delta.dx < -20) widget.onCancelRecording();
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.danger.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('Recording ${widget.recordingDuration}', style: AppText.message.copyWith(color: AppColors.danger)),
        const Spacer(),
        Text('← slide to cancel', style: AppText.timestamp.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: widget.onSend,
      child: Container(
        key: const ValueKey('send'),
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: widget.isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send, color: Colors.white, size: 16),
      ),
    );
  }
}

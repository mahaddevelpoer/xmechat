import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onCamera;
  final VoidCallback? onAttach;
  final VoidCallback? onStartRecord;
  final VoidCallback? onStopRecord;
  final VoidCallback? onEmoji;
  final bool isRecording;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onCamera,
    this.onAttach,
    this.onStartRecord,
    this.onStopRecord,
    this.onEmoji,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: AppColors.bgSecondary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.textHint, size: 28),
            onPressed: onAttach,
          ),
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textHint, size: 26),
            onPressed: onEmoji ?? () {},
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  fillColor: Colors.transparent,
                ),
                maxLines: 6,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              bool hasText = value.text.trim().isNotEmpty;
              return IconButton(
                icon: Icon(
                  hasText ? Icons.send : (isRecording ? Icons.stop : Icons.mic),
                  color: isRecording ? AppColors.error : AppColors.textHint,
                  size: 26,
                ),
                onPressed: hasText 
                    ? onSend 
                    : (isRecording ? onStopRecord : onStartRecord),
              );
            },
          ),
        ],
      ),
    );
  }
}

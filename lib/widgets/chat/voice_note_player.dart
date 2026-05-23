import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme.dart';
import '../common/user_avatar.dart';

/// Standalone voice note player widget.
/// Used inside message bubbles for audio messages.
/// Manages its own AudioPlayer lifecycle.
class VoiceNotePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final String? senderAvatarUrl;
  final String senderName;
  final bool isSent;

  const VoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    this.senderAvatarUrl,
    required this.senderName,
    required this.isSent,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late final AudioPlayer _player;
  double _speed = 1.0;
  bool _loading = false;
  bool _error = false;

  static const _speeds = [1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });
    _player.positionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_error) return;

    if (_player.playing) {
      await _player.pause();
      return;
    }

    // Load if not loaded yet
    if (_player.duration == null) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(widget.audioUrl);
        await _player.setSpeed(_speed);
      } catch (_) {
        if (mounted) setState(() { _loading = false; _error = true; });
        return;
      }
      if (mounted) setState(() => _loading = false);
    }

    await _player.play();
  }

  void _cycleSpeed() {
    final idx = _speeds.indexOf(_speed);
    final next = _speeds[(idx + 1) % _speeds.length];
    setState(() => _speed = next);
    _player.setSpeed(next);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final position = _player.position;
    final duration = _player.duration ?? Duration(seconds: widget.durationSeconds);
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isPlaying = _player.playing;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          // Avatar (shown for received messages)
          if (!widget.isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: UserAvatar(
                imageUrl: widget.senderAvatarUrl,
                name: widget.senderName,
                size: 32,
              ),
            ),

          // Play / pause button
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.isSent ? AppColors.accent : AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isSent
                            ? AppColors.white
                            : AppColors.accent,
                      ),
                    )
                  : _error
                      ? Icon(Icons.error_outline,
                          size: 18,
                          color: widget.isSent
                              ? AppColors.white
                              : AppColors.danger)
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                          color: widget.isSent
                              ? AppColors.white
                              : AppColors.accent,
                        ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform progress + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    color: AppColors.accent,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(isPlaying || position.inSeconds > 0
                      ? position
                      : duration),
                  style: AppText.timestamp,
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Speed button
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_speed == 1.0 ? '1' : _speed == 1.5 ? '1.5' : '2'}x',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String mediaUrl;
  final int durationSeconds;
  final AudioPlayer player;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final double speed;
  final ValueChanged<double> onSpeedChange;

  const VoiceNotePlayer({
    super.key,
    required this.mediaUrl,
    required this.durationSeconds,
    required this.player,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.onSeek,
    required this.speed,
    required this.onSpeedChange,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(20, (i) => (4 + (DateTime.now().millisecondsSinceEpoch % 17 + i * 3) % 18).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onPlayPause,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTapDown: (details) {
              final renderBox = context.findRenderObject() as RenderBox;
              final localPos = renderBox.globalToLocal(details.globalPosition);
              final width = 120.0;
              final fraction = (localPos.dx - 40) / width;
              widget.onSeek(fraction.clamp(0.0, 1.0));
            },
            child: SizedBox(
              width: 120,
              height: 28,
              child: CustomPaint(
                size: const Size(120, 28),
                painter: _WaveformPainter(
                  bars: _barHeights,
                  progress: widget.progress,
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.border,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.isPlaying
                ? _formatDuration((widget.progress * widget.durationSeconds).round())
                : _formatDuration(widget.durationSeconds),
            style: AppText.timestamp,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              final speeds = [1.0, 1.5, 2.0, 1.0];
              final idx = speeds.indexOf(widget.speed);
              widget.onSpeedChange(speeds[(idx + 1) % speeds.length]);
            },
            child: Text('${widget.speed.toStringAsFixed(widget.speed == 1.0 ? 0 : 1)}x', style: AppText.timestamp.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int sec) {
    final m = (sec ~/ 60).toString();
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / bars.length;
    for (int i = 0; i < bars.length; i++) {
      final x = i * barWidth + 2;
      final barH = bars[i].clamp(4.0, size.height);
      final isActive = i / bars.length <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2 - 2, size.height / 2),
            width: 3,
            height: barH,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = isActive ? activeColor : inactiveColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => old.progress != progress;
}

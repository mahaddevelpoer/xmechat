import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/call_service.dart';
import '../../widgets/common/user_avatar.dart';

class IncomingCallScreen extends ConsumerWidget {
  final CallModel call;

  const IncomingCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = call.type == CallType.video;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D1A0D).withOpacity(0.95),
              const Color(0xFF1A2E1A).withOpacity(0.95),
              const Color(0xFF0D1A0D).withOpacity(0.95),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background circles
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.05),
                ),
              ),
            ),
            // Glassmorphic card
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caller avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: UserAvatar(
                          imageUrl: null,
                          name: 'Caller',
                          size: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Caller name
                    FutureBuilder<UserModel?>(
                      future: ref.read(chatServiceProvider).getUserById(call.callerId),
                      builder: (_, snap) {
                        final name = snap.data?.name ?? 'Connecting...';
                        return Text(
                          name,
                          style: AppText.heading.copyWith(
                            color: AppColors.white,
                            fontSize: 28,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    // Call type
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                          style: AppText.bodyGrey.copyWith(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Connecting dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(),
                        _dot(),
                        _dot(),
                      ],
                    ),
                    const SizedBox(height: 48),
                    // Accept / Decline buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Decline
                        _CallActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          color: AppColors.danger,
                          onTap: () async {
                            await CallService.instance.stopRingtone();
                            await ref.read(webrtcServiceProvider).rejectCall(call.id);
                            if (context.mounted) context.pop();
                          },
                        ),
                        // Accept
                        _CallActionButton(
                          icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          label: 'Accept',
                          color: AppColors.accent,
                          onTap: () async {
                            await CallService.instance.stopRingtone();
                            if (!context.mounted) return;
                            final route = isVideo ? '/video-call' : '/voice-call';
                            context.pushReplacement('$route/${call.id}', extra: {
                              'isCaller': false,
                              'user': null,
                              'sdpOffer': call.sdpOffer,
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppText.caption.copyWith(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

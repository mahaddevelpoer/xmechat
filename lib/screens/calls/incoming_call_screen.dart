import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class IncomingCallScreen extends ConsumerWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = call.type == CallType.video;
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: ref.read(chatServiceProvider).getUserById(call.callerId),
          builder: (_, snap) {
            final caller = snap.data;
            return Column(children: [
              const SizedBox(height: 80),
              Text(isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 30),
              UserAvatar(url: caller?.avatarUrl, name: caller?.name ?? '?', radius: 60),
              const SizedBox(height: 24),
              Text(caller?.name ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  // Decline
                  GestureDetector(
                    onTap: () async {
                      await ref.read(webrtcServiceProvider).rejectCall(call.id);
                      if (!context.mounted) return;
                      context.pop();
                    },
                    child: Column(children: [
                      Container(
                        width: 65, height: 65,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  // Accept
                  GestureDetector(
                    onTap: () async {
                      await ref.read(webrtcServiceProvider).answerCall(call.id, call.sdpOffer, isVideo: isVideo);
                      if (!context.mounted) return;
                      context.pop();
                      final route = isVideo ? '/video-call/${call.id}' : '/voice-call/${call.id}';
                      context.push(route, extra: {'isCaller': false, 'user': caller});
                    },
                    child: Column(children: [
                      Container(
                        width: 65, height: 65,
                        decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle),
                        child: Icon(isVideo ? Icons.videocam : Icons.call, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 60),
            ]);
          },
        ),
      ),
    );
  }
}

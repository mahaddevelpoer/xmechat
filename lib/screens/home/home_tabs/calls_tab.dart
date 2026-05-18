import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/user_avatar.dart';

class CallsTab extends ConsumerWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callsAsync = ref.watch(callHistoryProvider);
    return callsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (calls) {
        if (calls.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_outlined, size: 80, color: AppColors.textHint),
              SizedBox(height: 16),
              Text('No calls yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(callHistoryProvider),
          child: ListView.separated(
            itemCount: calls.length,
            separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
            itemBuilder: (_, i) => _CallTile(call: calls[i]),
          ),
        );
      },
    );
  }
}

class _CallTile extends ConsumerWidget {
  final CallModel call;
  const _CallTile({required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.read(authServiceProvider).currentUserId;
    final isOutgoing = call.callerId == myId;
    final other = isOutgoing ? call.receiver : call.caller;

    Color statusColor = AppColors.textSecondary;
    IconData statusIcon = Icons.call_made;
    if (!isOutgoing) statusIcon = Icons.call_received;
    if (call.status == CallStatus.missed) { statusColor = AppColors.error; statusIcon = Icons.call_missed; }
    if (call.status == CallStatus.rejected) statusColor = AppColors.error;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: UserAvatar(url: other?.avatarUrl, name: other?.name ?? '?', radius: 26),
      title: Text(other?.name ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
      subtitle: Row(children: [
        Icon(statusIcon, size: 14, color: statusColor),
        const SizedBox(width: 4),
        Text(
          '${isOutgoing ? "Outgoing" : "Incoming"} • ${call.type == CallType.video ? "Video" : "Voice"}',
          style: TextStyle(color: statusColor, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text('• ${timeago.format(call.createdAt)}',
          style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
      ]),
      trailing: IconButton(
        icon: Icon(
          call.type == CallType.video ? Icons.videocam_outlined : Icons.call_outlined,
          color: AppColors.accentGreen,
        ),
        onPressed: () async {
          if (other == null) return;
          final chatService = ref.read(chatServiceProvider);
          final chatId = await chatService.getOrCreateChat(other.id);
          if (!context.mounted) return;
          final route = call.type == CallType.video ? '/video-call' : '/voice-call';
          final webrtc = ref.read(webrtcServiceProvider);
          final callId = await webrtc.initiateCall(other.id, isVideo: call.type == CallType.video);
          if (!context.mounted) return;
          context.push('$route/$callId', extra: {'isCaller': true, 'user': other});
        },
      ),
    );
  }
}

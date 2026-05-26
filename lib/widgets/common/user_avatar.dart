import 'package:flutter/material.dart';
import '../../theme.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final double onlineDotSize;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 44,
    this.showOnline = false,
    this.isOnline = false,
    this.onlineDotSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.accentLight,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(letter, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent, fontSize: size * 0.4))
          : null,
    );

    if (!showOnline) return avatar;

    return Stack(
      children: [
        avatar,
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: onlineDotSize,
              height: onlineDotSize,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A reusable avatar widget used throughout XmeChat.
///
/// * [url] – Network image url for the user's avatar; if null a placeholder with
///   the user's initials is shown.
/// * [name] – Full name of the user; used to generate initials when no image is
///   available.
/// * [isOnline] – When true a small green dot is displayed at the bottom‑right
///   corner to indicate the user is currently online.
/// * [radius] – Avatar size; defaults to 24.
class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final bool isOnline;
  final double radius;

  const UserAvatar({
    super.key,
    this.url,
    required this.name,
    this.isOnline = false,
    this.radius = 24,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.bgSecondary,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(
              _initials,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.6,
              ),
            )
          : null,
    );

    if (!isOnline) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.35,
            height: radius * 0.35,
            decoration: BoxDecoration(
              color: AppColors.accentGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

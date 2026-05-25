import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';

/// A reusable circular avatar with optional online indicator dot.
/// Falls back to an initials circle when no URL is provided.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppSizes.avatarMd,
    this.showOnline = false,
    this.isOnline = false,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color get _bgColor {
    // Deterministic color from name
    const colors = [
      Color(0xFF2B7A0B),
      Color(0xFF1565C0),
      Color(0xFF6A1B9A),
      Color(0xFFC62828),
      Color(0xFF00695C),
      Color(0xFFE65100),
      Color(0xFF4527A0),
      Color(0xFF283593),
    ];
    if (name.isEmpty) return colors[0];
    final idx = name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: _buildImage(),
      ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    if (!showOnline) return avatar;

    final dotSize = size * 0.28;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.online : AppColors.textHint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialsCircle(),
        errorWidget: (_, __, ___) => _initialsCircle(),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      color: _bgColor,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppText.custom(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          height: 1,
        ),
      ),
    );
  }
}

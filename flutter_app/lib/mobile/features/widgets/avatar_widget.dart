import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xdu_treehole_web/core/config/app_config.dart';
import '../../core/theme/mobile_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final double radius;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.nickname,
    this.radius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = MobileTheme.primaryOf(context);
    final String resolved = avatarUrl?.trim().isNotEmpty == true
        ? AppConfig.resolveUrl(avatarUrl!)
        : '';
    final String label = nickname.trim().isEmpty
        ? '匿'
        : nickname.trim().substring(0, 1);

    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolved,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                _buildPlaceholder(label, primaryColor),
            errorWidget: (context, url, error) =>
                _buildPlaceholder(label, primaryColor),
          ),
        ),
      );
    }

    return _buildPlaceholder(label, primaryColor);
  }

  Widget _buildPlaceholder(String label, Color primaryColor) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}

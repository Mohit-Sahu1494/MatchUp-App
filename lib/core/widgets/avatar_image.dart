import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AvatarImage extends StatelessWidget {
  final String? url;
  final double radius;
  final bool isOnline;
  final bool showPresence;

  const AvatarImage({
    super.key,
    this.url,
    this.radius = 24.0,
    this.isOnline = false,
    this.showPresence = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: ClipOval(
            child: url != null && url!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.person,
                      size: radius,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: radius,
                    color: AppColors.primary,
                  ),
          ),
        ),
        if (showPresence)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.accent : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

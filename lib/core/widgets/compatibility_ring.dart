import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CompatibilityRing extends StatelessWidget {
  final int score;
  final double size;
  final double strokeWidth;
  final bool showLabel;
  final bool showCaption;
  final bool compact;

  const CompatibilityRing({
    super.key,
    required this.score,
    this.size = 62.0,
    this.strokeWidth = 4.5,
    this.showLabel = true,
    this.showCaption = false,
    this.compact = false,
  });

  String get levelText {
    if (score < 30) return 'LOW';
    if (score < 60) return 'MEDIUM';
    return 'HIGH MATCH';
  }

  Color get levelColor {
    if (score < 30) return Colors.amber.shade700;
    if (score < 60) return AppColors.primary;
    return AppColors.likeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (score.clamp(0, 100)) / 100.0;
    final color = levelColor;

    Widget ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.2)),
          ),
          // Active progress ring
          CircularProgressIndicator(
            value: progress,
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          // Central percentage
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (!compact && size >= 58)
                Text(
                  score >= 60 ? 'HIGH' : (score >= 30 ? 'MED' : 'LOW'),
                  style: TextStyle(
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!showLabel && !showCaption) {
      return ring;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        if (showLabel) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(
              levelText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
        ],
        if (showCaption) ...[
          const SizedBox(height: 4),
          const Text(
            'Based on your interests, hobbies and preferences.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

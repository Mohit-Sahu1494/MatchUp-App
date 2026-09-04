import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class MoodOption {
  final String key;
  final String emoji;
  final String label;
  final String greeting;

  const MoodOption({
    required this.key,
    required this.emoji,
    required this.label,
    required this.greeting,
  });
}

const List<MoodOption> kMoodOptions = [
  MoodOption(key: 'Happy', emoji: '😊', label: 'Happy', greeting: 'Great vibes today! ✨'),
  MoodOption(key: 'Calm', emoji: '😌', label: 'Calm', greeting: 'Take it easy and meet someone new. 🌿'),
  MoodOption(key: 'Excited', emoji: '🔥', label: 'Excited', greeting: 'High energy today! Let\'s make connections. 🔥'),
  MoodOption(key: 'Confident', emoji: '😎', label: 'Confident', greeting: 'Stepping out with style today! 😎'),
  MoodOption(key: 'Energetic', emoji: '🤩', label: 'Energetic', greeting: 'Ready to discover someone awesome? ⚡'),
  MoodOption(key: 'Loved', emoji: '🥰', label: 'Loved', greeting: 'Spreading warm campus love today. 🥰'),
  MoodOption(key: 'Neutral', emoji: '😐', label: 'Neutral', greeting: 'A steady day for friendly discoveries. ☕'),
  MoodOption(key: 'Sad', emoji: '😔', label: 'Sad', greeting: 'Maybe someone out there could brighten your day. 💛'),
  MoodOption(key: 'Tired', emoji: '😴', label: 'Tired', greeting: 'Take it easy. Discover at your own pace. 🌙'),
  MoodOption(key: 'Stressed', emoji: '😤', label: 'Stressed', greeting: 'Take a breath. Campus friends are here for you. 🍃'),
];

class DailyMoodDialog extends StatelessWidget {
  final Function(String mood)? onSelected;

  const DailyMoodDialog({super.key, this.onSelected});

  static String getGreeting(String? mood) {
    if (mood == null || mood.isEmpty) return 'Discover fellow students on campus! ✨';
    final found = kMoodOptions.firstWhere((m) => m.key.toLowerCase() == mood.toLowerCase(), orElse: () => kMoodOptions[0]);
    return found.greeting;
  }

  static String getEmoji(String? mood) {
    if (mood == null || mood.isEmpty) return '✨';
    final found = kMoodOptions.firstWhere((m) => m.key.toLowerCase() == mood.toLowerCase(), orElse: () => kMoodOptions[0]);
    return found.emoji;
  }

  /// Automatically checks if mood was submitted today. If not, shows dialog once.
  static Future<String?> checkAndPromptToday(BuildContext context) async {
    try {
      final res = await ApiClient().get(ApiEndpoints.todayMood);
      if (res.data['success'] == true) {
        final data = res.data['data'];
        if (data['isSubmitted'] == true) {
          return data['mood'];
        }
      }
      if (context.mounted) {
        return await show(context);
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> show(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const DailyMoodDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      title: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            'How are you feeling today?',
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 4),
          Text(
            'We\'ll adapt your campus discover vibe for today',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemCount: kMoodOptions.length,
          itemBuilder: (ctx, index) {
            final mood = kMoodOptions[index];
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () async {
                Navigator.of(ctx).pop(mood.key);
                try {
                  await ApiClient().post(ApiEndpoints.mood, data: {'mood': mood.key});
                } catch (_) {}
                onSelected?.call(mood.key);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mood.label,
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.sm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

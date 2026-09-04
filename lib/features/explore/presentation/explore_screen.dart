import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/compatibility_ring.dart';
import '../../profile/models/profile_model.dart';
import '../../gifts/presentation/gift_modal_sheet.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final List<String> _categories = [
    'Dating',
    'Friendship',
    'Serious Relationship',
    'Study Partner',
    'Hangout Partner',
    'Networking',
    'Casual Dating',
    'Long-term Relationship',
    'Just Chat',
    'Other'
  ];

  String _selectedCategory = 'Dating';
  List<ProfileModel> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _fetchCategoryProfiles();
  }

  Future<void> _fetchCategoryProfiles({bool isRefresh = false}) async {
    if (isRefresh) {
      _page = 1;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(
        ApiEndpoints.relationshipFeed(_selectedCategory),
        queryParameters: {'page': _page, 'limit': 20},
      );

      if (res.data['success'] == true) {
        final data = res.data['data'];
        final List list = data['profiles'] ?? [];
        setState(() {
          _profiles = list.map((item) => ProfileModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data['message'] ?? 'Failed to load profiles';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load connections. Please check your network.';
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
      _page = 1;
    });
    _fetchCategoryProfiles();
  }

  Future<void> _handleQuickLike(ProfileModel profile) async {
    try {
      final res = await ApiClient().post(ApiEndpoints.swipe, data: {
        'targetUserId': profile.userId,
        'action': 'like',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.data['data']?['isMatch'] == true
                  ? 'It\'s a Match with ${profile.name}! 🎉'
                  : 'Liked ${profile.name}! ❤️',
            ),
            backgroundColor: res.data['data']?['isMatch'] == true ? AppColors.secondary : AppColors.likeGreen,
          ),
        );
      }
    } catch (_) {}
  }

  void _showProfileModal(ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  AvatarImage(url: profile.profilePhoto, radius: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name, style: AppTypography.displayMedium.copyWith(fontSize: 22)),
                        Text(
                          '${profile.college} • ${profile.course}',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                        ),
                        Text('Year ${profile.year} • @${profile.username}', style: AppTypography.labelSmall.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  CompatibilityRing(score: profile.compatibilityScore, size: 52, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text('Looking For', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: profile.relationshipPreferences.map((r) {
                  return Chip(
                    label: Text(r),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('About Me', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.bio.isNotEmpty ? profile.bio : 'Campus student connecting on MatchUp!',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Gift'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        GiftModalSheet.show(context, receiverId: profile.userId, receiverName: profile.name);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.favorite),
                      label: const Text('Like Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.likeGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleQuickLike(profile);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchCategoryProfiles(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle / Prompt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
            child: Text(
              'Looking for...',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),

          // Horizontal Category Filter Chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;

                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade200,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 1,
                  ),
                  onSelected: (_) => _onCategorySelected(cat),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),

          // Profiles Feed / States
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: AppSpacing.md),
                            Text(_errorMessage!, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.md),
                            ElevatedButton(
                              onPressed: () => _fetchCategoryProfiles(isRefresh: true),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _profiles.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: 'No Profiles in "$_selectedCategory"',
                            description: 'No one has selected "$_selectedCategory" yet. Broaden your search or check other categories.',
                            buttonTitle: 'Try Another Category',
                            onButtonPressed: () => _onCategorySelected('Friendship'),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetchCategoryProfiles(isRefresh: true),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: _profiles.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                              itemBuilder: (ctx, index) {
                                final p = _profiles[index];
                                return _buildProfileCard(p, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ProfileModel profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _showProfileModal(profile),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarImage(url: profile.profilePhoto, radius: 30),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.age > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  '${profile.age}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profile.college} • ${profile.course}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Year ${profile.year}',
                          style: AppTypography.labelSmall.copyWith(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  CompatibilityRing(
                    score: profile.compatibilityScore,
                    size: 52,
                    showLabel: true,
                    compact: true,
                  ),
                ],
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  profile.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  // Relationship Preference Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 12, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          _selectedCategory,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Quick Gift
                  IconButton(
                    icon: const Icon(Icons.card_giftcard, size: 20, color: AppColors.warning),
                    tooltip: 'Send Gift',
                    onPressed: () => GiftModalSheet.show(context, receiverId: profile.userId, receiverName: profile.name),
                  ),
                  // Quick Like
                  IconButton(
                    icon: const Icon(Icons.favorite, size: 20, color: AppColors.likeGreen),
                    tooltip: 'Like Profile',
                    onPressed: () => _handleQuickLike(profile),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

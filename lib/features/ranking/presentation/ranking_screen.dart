import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../models/ranking_model.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<RankingItemModel> _leaderboard = [];
  Map<String, dynamic>? _myRank;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().get(ApiEndpoints.ranking);
      if (res.data['success'] == true) {
        final List list = res.data['data']['leaderboard'] ?? [];
        setState(() {
          _leaderboard = list.map((item) => RankingItemModel.fromJson(item)).toList();
          _myRank = res.data['data']['myRank'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Leaderboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRankings),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRankings,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                children: [
                  // Personal Rank Card
                  if (_myRank != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.military_tech, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Campus Standing',
                                  style: AppTypography.labelSmall.copyWith(color: Colors.white70),
                                ),
                                Text(
                                  'Rank #${_myRank!['rank']}',
                                  style: AppTypography.displayMedium.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_myRank!['totalScore']} pts',
                            style: AppTypography.titleLarge.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Top 3 Podium
                  if (_leaderboard.length >= 3) ...[
                    _buildPodium(_leaderboard.sublist(0, 3)),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Full Ranking List
                  Text('All Standings', style: AppTypography.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _leaderboard.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final item = _leaderboard[index];
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '#${item.rank}',
                                style: AppTypography.titleMedium.copyWith(
                                  color: item.rank <= 3 ? AppColors.warning : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            AvatarImage(url: item.profilePhoto, radius: 20),
                          ],
                        ),
                        title: Text(item.name, style: AppTypography.titleMedium),
                        subtitle: Text('${item.course} • Yr ${item.year}', style: AppTypography.bodyMedium),
                        trailing: Text(
                          '${item.totalScore} pts',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodium(List<RankingItemModel> topThree) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // #2 Silver
        _buildPodiumColumn(topThree[1], rank: 2, height: 110, badge: '🥈', color: Colors.grey.shade400),
        const SizedBox(width: 8),
        // #1 Gold Crown
        _buildPodiumColumn(topThree[0], rank: 1, height: 140, badge: '👑', color: AppColors.warning),
        const SizedBox(width: 8),
        // #3 Bronze
        _buildPodiumColumn(topThree[2], rank: 3, height: 90, badge: '🥉', color: Colors.brown.shade300),
      ],
    );
  }

  Widget _buildPodiumColumn(RankingItemModel item, {
    required int rank,
    required double height,
    required String badge,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(badge, style: const TextStyle(fontSize: 22)),
          AvatarImage(url: item.profilePhoto, radius: rank == 1 ? 26 : 22),
          const SizedBox(height: 4),
          Text(
            item.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${item.totalScore} pts',
            style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTypography.displayMedium.copyWith(color: color, fontSize: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

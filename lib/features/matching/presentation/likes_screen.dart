import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/compatibility_ring.dart';
import '../models/like_model.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../gifts/presentation/gift_modal_sheet.dart';
import '../../calling/services/webrtc_service.dart';
import '../../calling/presentation/call_screen.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  List<LikeModel> _likes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLikes();
  }

  Future<void> _fetchLikes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiEndpoints.likes);
      if (res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _likes = list.map((item) => LikeModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res.data['message'] ?? 'Failed to load likes';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not fetch likes. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _openChat(LikeModel like) {
    if (like.conversationId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversationId: like.conversationId!,
            recipientId: like.targetUserId,
            recipientName: like.name,
            recipientPhoto: like.profilePhoto,
          ),
        ),
      ).then((_) => _fetchLikes());
    }
  }

  Future<void> _startCall(LikeModel like, {required bool isVideo}) async {
    final webrtc = WebRTCService();
    await webrtc.initRenderers();
    await webrtc.startCall(like.targetUserId, isVideo: isVideo);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            webrtcService: webrtc,
            peerName: like.name,
            peerPhoto: like.profilePhoto,
            isVideo: isVideo,
          ),
        ),
      );
    }
  }

  Future<void> _handleRemoveLike(LikeModel like) async {
    final isMatched = like.isMatched;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMatched ? 'Unmatch Student' : 'Remove Like'),
        content: Text(
          isMatched
              ? 'Are you sure you want to unmatch with ${like.name}? Chatting and calls will be disabled.'
              : 'Remove your like for ${like.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.skipRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMatched ? 'Unmatch' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient().delete(ApiEndpoints.removeLike(like.targetUserId));
      if (res.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isMatched ? 'Unmatched ${like.name}' : 'Removed like for ${like.name}')),
          );
        }
        _fetchLikes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove like')),
        );
      }
    }
  }

  void _showProfileModal(LikeModel like) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                  AvatarImage(url: like.profilePhoto, radius: 36, isOnline: like.isOnline, showPresence: true),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(like.name, style: AppTypography.displayMedium.copyWith(fontSize: 22)),
                        Text('${like.college} • ${like.course}', style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
                        Text('Year ${like.year} • @${like.username}', style: AppTypography.labelSmall.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  CompatibilityRing(score: like.compatibilityScore, size: 52, compact: true),
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
                children: like.relationshipPreferences.map((r) => Chip(label: Text(r))).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('About', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(like.bio.isNotEmpty ? like.bio : 'MatchUp campus student', style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Send Gift'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        GiftModalSheet.show(context, receiverId: like.targetUserId, receiverName: like.name);
                      },
                    ),
                  ),
                  if (like.isMatched) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openChat(like);
                        },
                      ),
                    ),
                  ],
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
        title: Row(
          children: [
            const Text('Likes'),
            const SizedBox(width: 8),
            if (!_isLoading && _likes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${_likes.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLikes),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: AppSpacing.md),
                      Text(_errorMessage!, style: AppTypography.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(onPressed: _fetchLikes, child: const Text('Try Again')),
                    ],
                  ),
                )
              : _likes.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border,
                      title: 'You Haven\'t Liked Anyone Yet',
                      description: 'Swipe right on student profiles in Discover to see the people you like here!',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchLikes,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _likes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (ctx, index) {
                          final like = _likes[index];
                          return _buildLikeCard(like, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildLikeCard(LikeModel like, bool isDark) {
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Info, Compatibility Ring, Menu
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showProfileModal(like),
                  child: AvatarImage(
                    url: like.profilePhoto,
                    radius: 32,
                    isOnline: like.isOnline,
                    showPresence: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              like.name,
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 17),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Badge: "Matched" vs "Liked by you"
                          if (like.isMatched)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppColors.heartGradient,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: const Text(
                                'Matched 🎉',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: const Text(
                                'Liked by you',
                                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${like.college} • ${like.course}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Year ${like.year} • @${like.username}',
                        style: AppTypography.labelSmall.copyWith(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                CompatibilityRing(
                  score: like.compatibilityScore,
                  size: 52,
                  showLabel: true,
                  compact: true,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'profile') {
                      _showProfileModal(like);
                    } else if (val == 'remove') {
                      _handleRemoveLike(like);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'profile', child: Text('View Profile')),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        like.isMatched ? 'Unmatch' : 'Remove Like',
                        style: const TextStyle(color: AppColors.skipRed),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Bio Preview
            if (like.bio.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                like.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),

            // Bottom Actions Row
            Row(
              children: [
                // Relationship Preference
                if (like.relationshipPreferences.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      like.relationshipPreferences.first,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),

                const Spacer(),

                // Send Gift (Always Available)
                IconButton(
                  icon: const Icon(Icons.card_giftcard, size: 20, color: AppColors.warning),
                  tooltip: 'Send Gift',
                  onPressed: () => GiftModalSheet.show(context, receiverId: like.targetUserId, receiverName: like.name),
                ),

                // Communication Actions (Enabled only if Matched)
                if (like.isMatched) ...[
                  IconButton(
                    icon: const Icon(Icons.call_outlined, size: 20, color: AppColors.primary),
                    tooltip: 'Audio Call',
                    onPressed: () => _startCall(like, isVideo: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined, size: 22, color: AppColors.primary),
                    tooltip: 'Video Call',
                    onPressed: () => _startCall(like, isVideo: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.secondary),
                    tooltip: 'Message',
                    onPressed: () => _openChat(like),
                  ),
                ] else ...[
                  // If one-sided like, show subtle hint
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'Waiting for mutual like ⏳',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

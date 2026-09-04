import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/confession_model.dart';
import 'create_confession_screen.dart';
import 'confession_comments_sheet.dart';

class ConfessionsScreen extends StatefulWidget {
  const ConfessionsScreen({super.key});

  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  List<ConfessionModel> _confessions = [];
  bool _isLoading = true;
  String _activeFilter = 'all'; // 'all' or 'trending'

  @override
  void initState() {
    super.initState();
    _fetchConfessions();
  }

  Future<void> _fetchConfessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().get(
        ApiEndpoints.confessions,
        queryParameters: {'filter': _activeFilter},
      );
      if (res.data['success'] == true) {
        final List list = res.data['data']['confessions'] ?? [];
        setState(() {
          _confessions = list.map((item) => ConfessionModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(ConfessionModel confession) async {
    final originalHasLiked = confession.hasLiked;
    final originalLikes = confession.likesCount;

    // Optimistic UI update
    final nextHasLiked = !originalHasLiked;
    final nextLikes = nextHasLiked ? originalLikes + 1 : (originalLikes > 0 ? originalLikes - 1 : 0);

    setState(() {
      final index = _confessions.indexWhere((c) => c.id == confession.id);
      if (index != -1) {
        _confessions[index] = ConfessionModel(
          id: confession.id,
          text: confession.text,
          mediaUrl: confession.mediaUrl,
          isAnonymous: confession.isAnonymous,
          likesCount: nextLikes,
          commentsCount: confession.commentsCount,
          category: confession.category,
          hasLiked: nextHasLiked,
          isMine: confession.isMine,
          authorName: confession.authorName,
          authorPhoto: confession.authorPhoto,
          createdAt: confession.createdAt,
        );
      }
    });

    try {
      final res = await ApiClient().post(ApiEndpoints.confessionLike(confession.id));
      if (res.data['success'] == true) {
        final serverLikes = res.data['data']['likesCount'] ?? nextLikes;
        final serverHasLiked = res.data['data']['hasLiked'] ?? nextHasLiked;
        setState(() {
          final index = _confessions.indexWhere((c) => c.id == confession.id);
          if (index != -1) {
            _confessions[index] = ConfessionModel(
              id: confession.id,
              text: confession.text,
              mediaUrl: confession.mediaUrl,
              isAnonymous: confession.isAnonymous,
              likesCount: serverLikes,
              commentsCount: confession.commentsCount,
              category: confession.category,
              hasLiked: serverHasLiked,
              isMine: confession.isMine,
              authorName: confession.authorName,
              authorPhoto: confession.authorPhoto,
              createdAt: confession.createdAt,
            );
          }
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _confessions.indexWhere((c) => c.id == confession.id);
        if (index != -1) {
          _confessions[index] = ConfessionModel(
            id: confession.id,
            text: confession.text,
            mediaUrl: confession.mediaUrl,
            isAnonymous: confession.isAnonymous,
            likesCount: originalLikes,
            commentsCount: confession.commentsCount,
            category: confession.category,
            hasLiked: originalHasLiked,
            isMine: confession.isMine,
            authorName: confession.authorName,
            authorPhoto: confession.authorPhoto,
            createdAt: confession.createdAt,
          );
        }
      });
    }
  }

  void _openComments(ConfessionModel confession) {
    ConfessionCommentsSheet.show(
      context,
      confessionId: confession.id,
      currentCommentsCount: confession.commentsCount,
      onCommentCountChanged: (newCount) {
        setState(() {
          final index = _confessions.indexWhere((c) => c.id == confession.id);
          if (index != -1) {
            _confessions[index] = ConfessionModel(
              id: confession.id,
              text: confession.text,
              mediaUrl: confession.mediaUrl,
              isAnonymous: confession.isAnonymous,
              likesCount: confession.likesCount,
              commentsCount: newCount,
              category: confession.category,
              hasLiked: confession.hasLiked,
              isMine: confession.isMine,
              authorName: confession.authorName,
              authorPhoto: confession.authorPhoto,
              createdAt: confession.createdAt,
            );
          }
        });
      },
    );
  }

  Future<void> _deleteConfession(ConfessionModel confession) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Confession'),
        content: const Text('Are you sure you want to delete this confession post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.skipRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient().delete('${ApiEndpoints.confessions}/${confession.id}');
      if (res.data['success'] == true) {
        setState(() {
          _confessions.removeWhere((c) => c.id == confession.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confession deleted')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete confession')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Confessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: 'New Confession',
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateConfessionScreen()),
              );
              if (created == true) _fetchConfessions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Latest'),
                  selected: _activeFilter == 'all',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _activeFilter = 'all');
                      _fetchConfessions();
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: const Text('Trending 🔥'),
                  selected: _activeFilter == 'trending',
                  onSelected: (val) {
                    if (val) {
                      setState(() => _activeFilter = 'trending');
                      _fetchConfessions();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Confessions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _confessions.isEmpty
                    ? EmptyState(
                        icon: Icons.lock_outline,
                        title: 'No Confessions Yet',
                        description: 'Be the first to share an anonymous campus story or thought!',
                        buttonTitle: 'Drop Confession',
                        onButtonPressed: () async {
                          final created = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateConfessionScreen()),
                          );
                          if (created == true) _fetchConfessions();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchConfessions,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _confessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (ctx, index) {
                            final c = _confessions[index];
                            return _buildConfessionCard(c, isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfessionCard(ConfessionModel c, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author & Category Header
            Row(
              children: [
                AvatarImage(
                  url: c.isAnonymous ? 'https://api.dicebear.com/7.x/bottts/svg?seed=anon' : c.authorPhoto,
                  radius: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.isAnonymous ? 'Anonymous Student 🎭' : c.authorName,
                        style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${c.category} • ${DateFormat('MMM d, hh:mm a').format(c.createdAt)}',
                        style: AppTypography.labelSmall.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'copy') {
                      Clipboard.setData(ClipboardData(text: c.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied confession text')),
                      );
                    } else if (val == 'delete') {
                      _deleteConfession(c);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy Text')),
                    if (c.isMine)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Post', style: TextStyle(color: AppColors.skipRed)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Confession content
            Text(c.text, style: AppTypography.bodyLarge.copyWith(height: 1.4)),
            const SizedBox(height: AppSpacing.md),

            // Interactive Actions Bar (Like, Comment, Share)
            Row(
              children: [
                // Like Button
                InkWell(
                  onTap: () => _toggleLike(c),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          c.hasLiked ? Icons.favorite : Icons.favorite_border,
                          size: 19,
                          color: c.hasLiked ? AppColors.secondary : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${c.likesCount}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: c.hasLiked ? FontWeight.bold : FontWeight.normal,
                            color: c.hasLiked ? AppColors.secondary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Comment Button with active onTap
                InkWell(
                  onTap: () => _openComments(c),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          '${c.commentsCount}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Share / Copy Icon
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied confession text to share!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../models/confession_comment_model.dart';

class ConfessionCommentsSheet extends StatefulWidget {
  final String confessionId;
  final int currentCommentsCount;
  final ValueChanged<int> onCommentCountChanged;

  const ConfessionCommentsSheet({
    super.key,
    required this.confessionId,
    required this.currentCommentsCount,
    required this.onCommentCountChanged,
  });

  static void show(
    BuildContext context, {
    required String confessionId,
    required int currentCommentsCount,
    required ValueChanged<int> onCommentCountChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConfessionCommentsSheet(
        confessionId: confessionId,
        currentCommentsCount: currentCommentsCount,
        onCommentCountChanged: onCommentCountChanged,
      ),
    );
  }

  @override
  State<ConfessionCommentsSheet> createState() => _ConfessionCommentsSheetState();
}

class _ConfessionCommentsSheetState extends State<ConfessionCommentsSheet> {
  final _commentController = TextEditingController();
  final List<ConfessionCommentModel> _comments = [];
  bool _isLoading = true;
  bool _isAnonymous = true;
  bool _isPosting = false;
  late int _commentsCount;

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.currentCommentsCount;
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.confessionComments(widget.confessionId));
      if (res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _comments.clear();
          _comments.addAll(list.map((c) => ConfessionCommentModel.fromJson(Map<String, dynamic>.from(c))));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      final res = await ApiClient().post(
        ApiEndpoints.confessionComments(widget.confessionId),
        data: {
          'text': text,
          'isAnonymous': _isAnonymous,
        },
      );

      if (res.data['success'] == true && res.data['data'] != null) {
        final newComment = ConfessionCommentModel.fromJson(Map<String, dynamic>.from(res.data['data']));
        _commentController.clear();
        setState(() {
          _comments.add(newComment);
          _commentsCount++;
        });
        widget.onCommentCountChanged(_commentsCount);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Could not post comment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: keyboardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text('Comments', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '$_commentsCount',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No comments yet',
                              style: AppTypography.titleMedium.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Be the first to share your thoughts anonymously!',
                              style: AppTypography.labelSmall.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(height: AppSpacing.lg),
                        itemBuilder: (ctx, index) {
                          final c = _comments[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AvatarImage(
                                url: c.isAnonymous ? 'https://api.dicebear.com/7.x/bottts/svg?seed=anon' : c.authorPhoto,
                                radius: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.isAnonymous ? 'Anonymous Student 🎭' : c.authorName,
                                          style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        Text(
                                          DateFormat('hh:mm a').format(c.createdAt),
                                          style: AppTypography.labelSmall.copyWith(color: Colors.grey, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(c.text, style: AppTypography.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Composer Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Anonymous toggle chip
                      InkWell(
                        onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isAnonymous ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: _isAnonymous ? AppColors.primary : Colors.grey.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isAnonymous ? Icons.visibility_off : Icons.visibility,
                                size: 13,
                                color: _isAnonymous ? AppColors.primary : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isAnonymous ? 'Anonymous' : 'Public',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isAnonymous ? AppColors.primary : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                          ),
                          onSubmitted: (_) => _postComment(),
                        ),
                      ),
                      IconButton(
                        icon: _isPosting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: AppColors.primary),
                        onPressed: _postComment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

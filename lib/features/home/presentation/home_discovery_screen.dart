import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/compatibility_ring.dart';
import '../../profile/models/profile_model.dart';
import '../../gifts/presentation/gift_modal_sheet.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../../confession/presentation/confessions_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import 'daily_mood_dialog.dart';

class HomeDiscoveryScreen extends StatefulWidget {
  const HomeDiscoveryScreen({super.key});

  @override
  State<HomeDiscoveryScreen> createState() => _HomeDiscoveryScreenState();
}

class _HomeDiscoveryScreenState extends State<HomeDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  List<ProfileModel> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;
  String? _todayMood;
  int _unreadNotificationCount = 0;
  final Set<String> _swipedUserIds = {};
  final SocketService _socket = SocketService();

  // Swipe animation state
  Offset _dragOffset = Offset.zero;
  late AnimationController _animController;
  late Animation<Offset> _swipeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _swipeAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _setupNotificationSocket();
    _fetchFeed();
    _fetchNotificationCount();
    _checkDailyMood();
  }

  void _setupNotificationSocket() {
    _socket.connect().then((_) {
      _socket.on('new_notification', _handleNewNotification);
    }).catchError((_) {});
  }

  void _handleNewNotification(dynamic _) {
    if (mounted) {
      setState(() => _unreadNotificationCount++);
    }
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final response = await ApiClient().get(ApiEndpoints.notifications);
      if (!mounted || response.data is! Map || response.data['success'] != true) {
        return;
      }
      final notifications = response.data['data'] as List? ?? const [];
      setState(() => _unreadNotificationCount = notifications
          .where((item) => item is Map && item['isRead'] != true)
          .length);
    } catch (_) {
      // Discovery must still work when the notification endpoint is unavailable.
    }
  }

  @override
  void dispose() {
    _socket.off('new_notification', _handleNewNotification);
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkDailyMood() async {
    final mood = await DailyMoodDialog.checkAndPromptToday(context);
    if (mounted && mood != null) {
      setState(() => _todayMood = mood);
    }
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiEndpoints.discoveryFeed);
      if (res.data['success'] == true) {
        final List list = res.data['data']['profiles'] ?? [];
        final parsed = list
            .map((item) => ProfileModel.fromJson(item))
            .where((p) =>
                !_swipedUserIds.contains(p.userId) &&
                !_swipedUserIds.contains(p.id))
            .toList();
        setState(() {
          _profiles = parsed;
          _currentIndex = 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              res.data['message'] ?? 'Failed to load discovery feed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not connect to server. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSwipe(String action, {bool animated = false}) async {
    if (_currentIndex >= _profiles.length) return;
    final target = _profiles[_currentIndex];

    if (animated) {
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset = action == 'like'
          ? Offset(screenWidth * 1.5, 0)
          : Offset(-screenWidth * 1.5, 0);

      _swipeAnimation =
          Tween<Offset>(begin: Offset.zero, end: targetOffset).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );

      await _animController.forward();
      _animController.reset();
    }

    // Advance card
    setState(() {
      _currentIndex++;
      _dragOffset = Offset.zero;
    });

    final targetId = target.userId.isNotEmpty ? target.userId : target.id;
    if (target.userId.isNotEmpty) _swipedUserIds.add(target.userId);
    if (target.id.isNotEmpty) _swipedUserIds.add(target.id);

    try {
      final res = await ApiClient().post(ApiEndpoints.swipe, data: {
        'targetUserId': targetId,
        'action': action,
      });

      if (res.data['success'] == true && res.data['data']['isMatch'] == true) {
        if (mounted) {
          _showMatchCelebration(target, res.data['data']['conversationId']);
        }
      }
    } catch (e) {
      debugPrint('[Swipe Error] $e');
    }
  }

  void _showMatchCelebration(
      ProfileModel matchProfile, String? conversationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                gradient: AppColors.heartGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 48),
            ),
            const SizedBox(height: AppSpacing.md),
            Text("It's a Match! 🎉", style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "You and ${matchProfile.name} liked each other! Say hello and start chatting.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (conversationId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        conversationId: conversationId,
                        recipientId: matchProfile.userId,
                        recipientName: matchProfile.name,
                        recipientPhoto: matchProfile.profilePhoto,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Discovering',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDetails(ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AvatarImage(url: profile.profilePhoto, radius: 38),
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
                                style: AppTypography.displayMedium
                                    .copyWith(fontSize: 22),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.age > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  '${profile.age}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profile.college} • ${profile.course}',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.primary),
                        ),
                        Text(
                          'Year ${profile.year} • @${profile.username}',
                          style: AppTypography.labelSmall
                              .copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  CompatibilityRing(
                    score: profile.compatibilityScore,
                    size: 54,
                    showLabel: true,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Looking For / Relationship Preferences
              Text('Looking For',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: profile.relationshipPreferences.map((r) {
                  return Chip(
                    avatar: const Icon(Icons.favorite_border,
                        size: 16, color: AppColors.primary),
                    label: Text(r),
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // About Me
              Text('About Me',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.bio.isNotEmpty
                    ? profile.bio
                    : 'Campus student looking to connect with peers!',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Interests
              if (profile.interests.isNotEmpty) ...[
                Text('Interests',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.interests.map((i) {
                    return Chip(
                      label: Text(i),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Hobbies
              if (profile.hobbies.isNotEmpty) ...[
                Text('Hobbies',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.hobbies.map((h) {
                    return Chip(
                      label: Text(h),
                      backgroundColor: AppColors.secondary.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Send Gift'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        GiftModalSheet.show(context,
                            receiverId: profile.userId,
                            receiverName: profile.name);
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleSwipe('like', animated: true);
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
      body: SafeArea(
        child: Column(
          children: [
            // ============================================
            // 1. TOP HEADER & GREETING
            // ============================================
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                        children: [
                          Expanded(
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.sm)),
                                    child: const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.white,
                                        size: 20)),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                    child: Text('MatchUp',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.displayMedium
                                            .copyWith(fontSize: 22))),
                              ])),
                          // Campus Confessions Quick Action Button
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ConfessionsScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility_off,
                                      size: 15, color: AppColors.primary),
                                  if (constraints.maxWidth >= 360) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'Confessions',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Stack(clipBehavior: Clip.none, children: [
                              const Icon(Icons.notifications_outlined),
                              if (_unreadNotificationCount > 0)
                                Positioned(
                                    right: -5,
                                    top: -5,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                          minWidth: 16, minHeight: 16),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      decoration: const BoxDecoration(
                                          color: AppColors.skipRed,
                                          shape: BoxShape.circle),
                                      child: Text(
                                          _unreadNotificationCount > 9
                                              ? '9+'
                                              : '$_unreadNotificationCount',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    )),
                            ]),
                            tooltip: 'Notifications',
                            onPressed: () async {
                              setState(() => _unreadNotificationCount = 0);
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationsScreen()),
                              );
                              _fetchNotificationCount();
                            },
                          ),
                        ],
                      )),
            ),

            // ============================================
            // 2. DAILY MOOD VIBE BAR (Adaptive Microcopy)
            // ============================================
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () async {
                  final newMood = await DailyMoodDialog.show(context);
                  if (newMood != null) {
                    setState(() => _todayMood = newMood);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : Colors.indigo.shade50.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : Colors.indigo.shade100,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(DailyMoodDialog.getEmoji(_todayMood),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DailyMoodDialog.getGreeting(_todayMood),
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : Colors.indigo.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Change vibe',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ============================================
            // 3. HORIZONTALLY SCROLLABLE PEERS ROW
            // ============================================
            if (!_isLoading && _profiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: _profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (ctx, index) {
                    final p = _profiles[index];
                    final isCurrentDeck = index == _currentIndex;

                    return GestureDetector(
                      onTap: () => _showProfileDetails(p),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isCurrentDeck
                                  ? AppColors.primaryGradient
                                  : null,
                              border: isCurrentDeck
                                  ? null
                                  : Border.all(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                      width: 1.5,
                                    ),
                            ),
                            child: AvatarImage(url: p.profilePhoto, radius: 24),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 64,
                            child: Text(
                              p.name.split(' ').first,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: isCurrentDeck
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrentDeck ? AppColors.primary : null,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
            ],

            // ============================================
            // 4. MAIN TINDER SWIPE STACK & BUTTONS
            // ============================================
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: AppSpacing.md),
                              Text(_errorMessage!,
                                  style: AppTypography.bodyMedium,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton(
                                  onPressed: _fetchFeed,
                                  child: const Text('Try Again')),
                            ],
                          ),
                        )
                      : _currentIndex >= _profiles.length
                          ? EmptyState(
                              icon: Icons.explore_off_outlined,
                              title: "You've Seen Everyone!",
                              description:
                                  'New campus students join daily. Broaden your discovery or check back soon.',
                              buttonTitle: 'Refresh Discovery',
                              onButtonPressed: _fetchFeed,
                            )
                          : _buildSwipeStack(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeStack(bool isDark) {
    final currentProfile = _profiles[_currentIndex];
    final nextProfile = _currentIndex + 1 < _profiles.length
        ? _profiles[_currentIndex + 1]
        : null;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
            child: Stack(
              children: [
                // Background Card (Next in Deck)
                if (nextProfile != null)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.94,
                      child: Opacity(
                        opacity: 0.7,
                        child: _buildDiscoveryCard(nextProfile, isDark),
                      ),
                    ),
                  ),

                // Foreground Active Card with Pan Gesture
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final currentOffset = _animController.isAnimating
                          ? _swipeAnimation.value
                          : _dragOffset;

                      final angle = currentOffset.dx / 1200;

                      return Transform.translate(
                        offset: currentOffset,
                        child: Transform.rotate(
                          angle: angle,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() => _dragOffset += details.delta);
                      },
                      onPanEnd: (details) {
                        if (_dragOffset.dx > 120) {
                          _handleSwipe('like', animated: false);
                        } else if (_dragOffset.dx < -120) {
                          _handleSwipe('skip', animated: false);
                        } else {
                          setState(() => _dragOffset = Offset.zero);
                        }
                      },
                      onTap: () => _showProfileDetails(currentProfile),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildDiscoveryCard(currentProfile, isDark),

                          // LIKE stamp indicator on right drag
                          if (_dragOffset.dx > 40)
                            Positioned(
                              top: 24,
                              left: 24,
                              child: Transform.rotate(
                                angle: -0.25,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppColors.likeGreen, width: 3),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                  child: const Text(
                                    'LIKE',
                                    style: TextStyle(
                                      color: AppColors.likeGreen,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // PASS / NOPE stamp indicator on left drag
                          if (_dragOffset.dx < -40)
                            Positioned(
                              top: 24,
                              right: 24,
                              child: Transform.rotate(
                                angle: 0.25,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppColors.skipRed, width: 3),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                  child: const Text(
                                    'PASS',
                                    style: TextStyle(
                                      color: AppColors.skipRed,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ============================================
        // 5. ACTION BUTTONS ROW (Pass ❌, Gift 🎁, Info ℹ️, Like ❤️)
        // ============================================
        Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ❌ Pass Button
              _buildActionButton(
                icon: Icons.close,
                color: AppColors.skipRed,
                size: 54,
                tooltip: 'Pass / Skip',
                onTap: () => _handleSwipe('skip', animated: true),
              ),
              // 🎁 Send Gift
              _buildActionButton(
                icon: Icons.card_giftcard,
                color: AppColors.warning,
                size: 44,
                tooltip: 'Send Gift',
                onTap: () {
                  GiftModalSheet.show(
                    context,
                    receiverId: currentProfile.userId,
                    receiverName: currentProfile.name,
                  );
                },
              ),
              // ℹ️ View Profile Info
              _buildActionButton(
                icon: Icons.info_outline,
                color: AppColors.primary,
                size: 44,
                tooltip: 'View Profile',
                onTap: () => _showProfileDetails(currentProfile),
              ),
              // ❤️ Like Button
              _buildActionButton(
                icon: Icons.favorite,
                color: AppColors.likeGreen,
                size: 54,
                tooltip: 'Like Profile',
                onTap: () => _handleSwipe('like', animated: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryCard(ProfileModel profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile Photo
            CachedNetworkImage(
              imageUrl: profile.profilePhoto,
              fit: BoxFit.cover,
              placeholder: (_, __) => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? AppColors.darkSurface : Colors.grey[200],
                child: const Icon(Icons.person, size: 80, color: Colors.grey),
              ),
            ),

            // Subtle Vignette Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Top-Right Compatibility Ring
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: CompatibilityRing(
                  score: profile.compatibilityScore,
                  size: 48,
                  strokeWidth: 3.8,
                  showLabel: true,
                  compact: true,
                ),
              ),
            ),

            // Top-Left Suggested Tag (if fallback recommendation)
            if (profile.recommendationType == 'suggested')
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Suggested for you',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Profile Info Overlay
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name and Age
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: AppTypography.displayMedium.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.age > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${profile.age}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),

                  // College & Major
                  Text(
                    '${profile.college} • ${profile.course} (Yr ${profile.year})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),

                  // Relationship Preferences Chips
                  if (profile.relationshipPreferences.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          profile.relationshipPreferences.take(2).map((r) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.6),
                                width: 0.8),
                          ),
                          child: Text(
                            r,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Bio snippet
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],

                  // Interests snippet
                  if (profile.interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: profile.interests.take(3).map((i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            i,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required double size,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.45), width: 1.5),
          ),
          child: Icon(icon, color: color, size: size * 0.48),
        ),
      ),
    );
  }
}

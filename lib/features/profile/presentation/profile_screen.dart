import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../models/profile_model.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'blocked_users_screen.dart';
import '../../ranking/presentation/ranking_screen.dart';
import '../../confession/presentation/confessions_screen.dart';
import '../../auth/presentation/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _rankingData;
  int _matchesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final meRes = await ApiClient().get(ApiEndpoints.me);
      if (meRes.data['success'] == true) {
        _user = meRes.data['data']['user'];
        _profile = ProfileModel.fromJson(meRes.data['data']['profile']);
      }

      // Fetch ranking / stats
      try {
        final rankRes = await ApiClient().get(ApiEndpoints.ranking);
        if (rankRes.data['success'] == true) {
          _rankingData = rankRes.data['data'];
        }
      } catch (_) {}

      // Fetch matches count
      try {
        final matchRes = await ApiClient().get(ApiEndpoints.matches);
        if (matchRes.data['success'] == true) {
          final List matches = matchRes.data['data'] ?? [];
          _matchesCount = matches.length;
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[ProfileScreen] Fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of MatchUp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient().post(ApiEndpoints.logout);
    } catch (_) {}

    SocketService().disconnect();
    await TokenStorage.clearAll();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is irreversible. All your profile data, matches, and messages will be permanently removed. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.skipRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient().delete(ApiEndpoints.deleteAccount);
      if (res.data['success'] == true) {
        SocketService().disconnect();
        await TokenStorage.clearAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load profile'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(onPressed: _fetchProfileData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final myRankInfo = _rankingData?['myRank'];
    final int rankPos = myRankInfo?['rank'] ?? 1;
    final int totalPoints = myRankInfo?['totalScore'] ?? 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ============================================
              // 1. VISUALLY STRONG PROFILE HEADER
              // ============================================
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                      ),
                      child: AvatarImage(
                        url: _profile!.profilePhoto,
                        radius: 54,
                        showPresence: true,
                        isOnline: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Name & Age
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _profile!.name,
                    style: AppTypography.displayMedium.copyWith(fontSize: 24),
                  ),
                  if (_profile!.age > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_profile!.age}',
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

              // Username & Email
              Text(
                '@${_profile!.username} • ${_user?['email'] ?? ''}',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // College & Education Pill
              Container(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.of(context).size.width - (AppSpacing.xl * 2))
                      .clamp(0.0, double.infinity),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_profile!.college} • (Yr ${_profile!.year})',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Clear Primary Actions: Edit Profile & Settings
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _profile!)),
                        );
                        if (updated == true) _fetchProfileData();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ============================================
              // 2. PROFILE STATS (LIKES, MATCHES, RANKING)
              // ============================================
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Matches', '$_matchesCount', Icons.favorite, AppColors.secondary),
                      _buildStatDivider(isDark),
                      _buildStatItem('Credits', '${_user?['credits'] ?? 100}', Icons.token, AppColors.warning),
                      _buildStatDivider(isDark),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RankingScreen()),
                          );
                        },
                        child: _buildStatItem('Rank', '#$rankPos', Icons.emoji_events, AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ============================================
              // 3. ABOUT ME
              // ============================================
              _buildSectionTitle('About Me', Icons.person_outline),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _profile!.bio.isNotEmpty ? _profile!.bio : 'Introduce yourself to campus... Add a bio in Edit Profile!',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ============================================
              // 4. EDUCATION
              // ============================================
              _buildSectionTitle('Education', Icons.school_outlined),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _buildEduRow(Icons.account_balance, 'University', _profile!.college),
                      const Divider(height: AppSpacing.md),
                      _buildEduRow(Icons.book_outlined, 'Major / Course', _profile!.course),
                      const Divider(height: AppSpacing.md),
                      _buildEduRow(Icons.calendar_today_outlined, 'Year of Study', 'Year ${_profile!.year}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ============================================
              // 5. INTERESTS
              // ============================================
              _buildSectionTitle('Interests', Icons.interests_outlined),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _profile!.interests.isEmpty
                        ? Text('No interests selected yet', style: AppTypography.labelSmall)
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _profile!.interests.map((interest) {
                              return Chip(
                                label: Text(interest),
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ============================================
              // 6. HOBBIES
              // ============================================
              _buildSectionTitle('Hobbies', Icons.palette_outlined),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _profile!.hobbies.isEmpty
                        ? Text('No hobbies added yet', style: AppTypography.labelSmall)
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _profile!.hobbies.map((hobby) {
                              return Chip(
                                label: Text(hobby),
                                backgroundColor: AppColors.secondary.withOpacity(0.1),
                                side: BorderSide(color: AppColors.secondary.withOpacity(0.3)),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ============================================
              // 7. MENU / QUICK ACCESS TILES
              // ============================================
              _buildSectionTitle('Campus Hub & Account', Icons.apps),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.emoji_events, color: AppColors.warning),
                      title: const Text('Campus Rankings & Leaderboard'),
                      subtitle: Text('$totalPoints pts • Rank #$rankPos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RankingScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.visibility_off, color: AppColors.primary),
                      title: const Text('Campus Confessions'),
                      subtitle: const Text('Anonymous student stories & thoughts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ConfessionsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security, color: AppColors.primary),
                      title: const Text('Privacy & Visibility'),
                      subtitle: const Text('Manage what information is public'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.block, color: Colors.grey),
                      title: const Text('Blocked Users'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings, color: Colors.grey),
                      title: const Text('App Settings'),
                      subtitle: const Text('Appearance, themes, notifications'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Log Out & Delete Account
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                onPressed: _handleLogout,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _handleDeleteAccount,
                child: const Text('Delete Account', style: TextStyle(color: AppColors.skipRed, fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }

  Widget _buildEduRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.grey)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

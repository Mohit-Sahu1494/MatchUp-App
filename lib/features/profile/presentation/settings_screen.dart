import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/login_screen.dart';
import 'privacy_settings_screen.dart';
import 'blocked_users_screen.dart';
import '../../home/presentation/daily_mood_dialog.dart';
import '../../../core/services/fcm_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _matchAlerts = true;
  bool _messageAlerts = true;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }

  Future<void> _fetchAccountInfo() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.me);
      if (res.data['success'] == true && mounted) {
        setState(() {
          _userData = res.data['data']['user'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
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
      await FcmService.unregisterDeviceToken();
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
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                // ============================================
                // 1. THEME & APPEARANCE SECTION
                // ============================================
                _buildSectionHeader('Appearance & Theme'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('System Default'),
                        subtitle: const Text('Matches device appearance setting'),
                        secondary: const Icon(Icons.brightness_auto_outlined),
                        value: ThemeMode.system,
                        groupValue: currentThemeMode,
                        activeColor: AppColors.primary,
                        onChanged: (mode) {
                          if (mode != null) {
                            ref.read(themeProvider.notifier).setThemeMode(mode);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('Light Theme'),
                        subtitle: const Text('Crisp, bright look for daylight'),
                        secondary: const Icon(Icons.wb_sunny_outlined),
                        value: ThemeMode.light,
                        groupValue: currentThemeMode,
                        activeColor: AppColors.primary,
                        onChanged: (mode) {
                          if (mode != null) {
                            ref.read(themeProvider.notifier).setThemeMode(mode);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark Theme'),
                        subtitle: const Text('Sleek dark tones for low light'),
                        secondary: const Icon(Icons.nightlight_round_outlined),
                        value: ThemeMode.dark,
                        groupValue: currentThemeMode,
                        activeColor: AppColors.primary,
                        onChanged: (mode) {
                          if (mode != null) {
                            ref.read(themeProvider.notifier).setThemeMode(mode);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ============================================
                // 2. DAILY MOOD & DISCOVERY
                // ============================================
                _buildSectionHeader('Daily Mood & Discovery'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: ListTile(
                    leading: const Icon(Icons.mood, color: AppColors.secondary),
                    title: const Text('Change Today\'s Mood'),
                    subtitle: const Text('Select how you feel to adapt campus discover vibe'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => DailyMoodDialog.show(context),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ============================================
                // 3. NOTIFICATIONS SECTION
                // ============================================
                _buildSectionHeader('Notifications'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Stay updated on campus events'),
                        secondary: const Icon(Icons.notifications_outlined),
                        value: _pushNotifications,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _pushNotifications = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Match Alerts'),
                        subtitle: const Text('Notify when someone matches with you'),
                        secondary: const Icon(Icons.favorite_outline),
                        value: _matchAlerts,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _matchAlerts = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Direct Messages'),
                        subtitle: const Text('Notify on incoming chat messages'),
                        secondary: const Icon(Icons.chat_bubble_outline),
                        value: _messageAlerts,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _messageAlerts = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ============================================
                // 3. PRIVACY & SAFETY SECTION
                // ============================================
                _buildSectionHeader('Privacy & Safety'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.security_outlined),
                        title: const Text('Profile Visibility & Privacy'),
                        subtitle: const Text('Control who sees your academic & personal details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.block_outlined),
                        title: const Text('Blocked Users'),
                        subtitle: const Text('Manage your blocked accounts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ============================================
                // 4. ACCOUNT & SESSION SECTION
                // ============================================
                _buildSectionHeader('Account'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: const Text('Email address'),
                        subtitle: Text(_userData?['email'] ?? 'Verified account'),
                        trailing: const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.token_outlined),
                        title: const Text('Gift Credits Balance'),
                        subtitle: Text('${_userData?['credits'] ?? 100} credits available'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ============================================
                // 5. ACTIONS: LOGOUT & DELETE ACCOUNT
                // ============================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    onPressed: _handleLogout,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_forever, color: AppColors.skipRed),
                    label: const Text('Delete Account Permanently', style: TextStyle(color: AppColors.skipRed)),
                    onPressed: _handleDeleteAccount,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

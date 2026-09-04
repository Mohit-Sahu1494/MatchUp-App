import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  String _showCourse = 'public';
  String _showYear = 'public';
  String _showInterests = 'public';
  String _showSocialLinks = 'matched';
  bool _isProfileHidden = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _privacyOptions = ['public', 'matched', 'private'];

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.me);
      if (res.data['success'] == true) {
        final profile = res.data['data']['profile'];
        final priv = profile['privacySettings'] ?? {};
        setState(() {
          _showCourse = priv['showCourse'] ?? 'public';
          _showYear = priv['showYear'] ?? 'public';
          _showInterests = priv['showInterests'] ?? 'public';
          _showSocialLinks = priv['showSocialLinks'] ?? 'matched';
          _isProfileHidden = priv['isProfileHidden'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final res = await ApiClient().put(ApiEndpoints.updatePrivacy, data: {
        'showCourse': _showCourse,
        'showYear': _showYear,
        'showInterests': _showInterests,
        'showSocialLinks': _showSocialLinks,
        'isProfileHidden': _isProfileHidden,
      });

      if (res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.accent,
            content: Text('Privacy settings updated successfully!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update privacy settings.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Privacy Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Control Your Campus Visibility', style: AppTypography.displayMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Choose who sees your major, academic standing, and social handles on the campus network.',
                    style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Hide Entire Profile from Discovery
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text('Hide Profile from Discovery Deck'),
                    subtitle: const Text('Pause matching; existing matches can still message you'),
                    value: _isProfileHidden,
                    onChanged: (val) => setState(() => _isProfileHidden = val),
                  ),
                  const Divider(height: AppSpacing.xl),

                  _buildPrivacyRow('Course & Major Visibility', _showCourse, (val) => setState(() => _showCourse = val)),
                  const SizedBox(height: AppSpacing.md),

                  _buildPrivacyRow('Academic Year Visibility', _showYear, (val) => setState(() => _showYear = val)),
                  const SizedBox(height: AppSpacing.md),

                  _buildPrivacyRow('Interests & Hobbies', _showInterests, (val) => setState(() => _showInterests = val)),
                  const SizedBox(height: AppSpacing.md),

                  _buildPrivacyRow('Social Media Handles', _showSocialLinks, (val) => setState(() => _showSocialLinks = val)),
                  const SizedBox(height: AppSpacing.xxl),

                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      title: 'Save Privacy Settings',
                      isLoading: _isSaving,
                      onPressed: _saveSettings,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyRow(String title, String currentValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: _privacyOptions.map((opt) {
            final isSelected = currentValue == opt;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(opt[0].toUpperCase() + opt.substring(1)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) onChanged(opt);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

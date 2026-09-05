import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/avatar_image.dart';
import '../models/profile_model.dart';

const List<String> kPresetAvatars = [
  'https://api.dicebear.com/7.x/adventurer/png?seed=Alex',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Maya',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Sam',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Leo',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Zoe',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Jordan',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Kai',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Luna',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Robin',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Oliver',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Chloe',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Taylor',
];

const List<String> kAvailableInterests = [
  'Coding', 'AI & Machine Learning', 'Music', 'Sports', 'Photography',
  'Gaming', 'Startups', 'Design', 'Reading', 'Travel', 'Fitness', 'Cinema',
];

const List<String> kAvailableHobbies = [
  'Guitar', 'Chess', 'Basketball', 'Hiking', 'Cooking', 'Painting',
  'Badminton', 'Robotics', 'Podcasts', 'Anime', 'Writing', 'Yoga',
];

class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _collegeController;
  late final TextEditingController _courseController;
  late final TextEditingController _ageController;

  late String _selectedPhoto;
  late int _selectedYear;
  late List<String> _selectedInterests;
  late List<String> _selectedHobbies;
  late List<String> _selectedRelationships;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _bioController = TextEditingController(text: widget.profile.bio);
    _collegeController = TextEditingController(text: widget.profile.college);
    _courseController = TextEditingController(text: widget.profile.course);
    _ageController = TextEditingController(text: widget.profile.age.toString());

    _selectedPhoto = widget.profile.profilePhoto;
    _selectedYear = widget.profile.year;
    _selectedInterests = List<String>.from(widget.profile.interests);
    _selectedHobbies = List<String>.from(widget.profile.hobbies);
    _selectedRelationships = List<String>.from(widget.profile.relationshipPreferences);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final ageVal = int.tryParse(_ageController.text.trim()) ?? widget.profile.age;

    try {
      final res = await ApiClient().put(ApiEndpoints.me, data: {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'college': _collegeController.text.trim(),
        'course': _courseController.text.trim(),
        'year': _selectedYear,
        'age': ageVal,
        'profilePhoto': _selectedPhoto,
        'interests': _selectedInterests,
        'hobbies': _selectedHobbies,
        'relationshipPreferences': _selectedRelationships,
      });

      if (res.data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Update error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an Avatar', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Select a campus avatar for your profile card', style: AppTypography.labelSmall),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: GridView.builder(
                itemCount: kPresetAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final avatarUrl = kPresetAvatars[index];
                  final isChosen = _selectedPhoto == avatarUrl;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedPhoto = avatarUrl);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isChosen ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: AvatarImage(url: avatarUrl, radius: 32),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Custom Photo'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final formData = FormData.fromMap({
        'media': await MultipartFile.fromFile(
          pickedFile.path,
          filename: pickedFile.name,
        ),
        'type': 'avatar',
      });

      final res = await ApiClient().post(ApiEndpoints.uploadMedia, data: formData);

      if (res.data is Map && res.data['success'] == true) {
        final uploadedUrl = res.data['data']?['url'] ?? res.data['url'];
        if (uploadedUrl != null && mounted) {
          setState(() {
            _selectedPhoto = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar uploaded successfully!')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Upload failed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Avatar Selector Centerpiece
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AvatarImage(url: _selectedPhoto, radius: 52),
                  if (_isUploadingPhoto)
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.45),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _showAvatarPicker,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextButton(
                onPressed: _isUploadingPhoto ? null : _showAvatarPicker,
                child: const Text('Change Avatar'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Basic Info
            AppTextField(
              label: 'Full Name',
              hint: 'Your display name',
              controller: _nameController,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              label: 'College / University',
              hint: 'e.g. Stanford University',
              controller: _collegeController,
              prefixIcon: const Icon(Icons.account_balance_outlined),
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: 'Course / Major',
                    hint: 'e.g. Computer Science',
                    controller: _courseController,
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 1,
                  child: AppTextField(
                    label: 'Age',
                    hint: '20',
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Academic Year
            Text('Academic Year', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [1, 2, 3, 4].map((yr) {
                final selected = _selectedYear == yr;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('Year $yr'),
                      selected: selected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedYear = yr);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bio
            AppTextField(
              label: 'About Me / Bio',
              hint: 'Tell others about your vibe, passions, and goals...',
              controller: _bioController,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Interests Chips
            Text('Interests', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAvailableInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.18),
                  checkmarkColor: AppColors.primary,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Hobbies Chips
            Text('Hobbies', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAvailableHobbies.map((hobby) {
                final isSelected = _selectedHobbies.contains(hobby);
                return FilterChip(
                  label: Text(hobby),
                  selected: isSelected,
                  selectedColor: AppColors.secondary.withOpacity(0.18),
                  checkmarkColor: AppColors.secondary,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedHobbies.add(hobby);
                      } else {
                        _selectedHobbies.remove(hobby);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            // Looking For / Relationship Preferences
            Text('Looking For', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                'Dating',
                'Friendship',
                'Serious Relationship',
                'Casual Dating',
                'Long-term Relationship',
                'Study Partner',
                'Hangout Partner',
                'Networking',
                'Just Chat',
                'Other',
              ].map((rel) {
                final isSelected = _selectedRelationships.contains(rel);
                return FilterChip(
                  label: Text(rel),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.18),
                  checkmarkColor: AppColors.primary,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedRelationships.add(rel);
                      } else if (_selectedRelationships.length > 1) {
                        _selectedRelationships.remove(rel);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),

            SizedBox(
              width: double.infinity,
              child: AppButton(
                title: 'Save Profile',
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import 'verify_email_screen.dart';
import '../../../navigation/main_bottom_nav.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  // Profile data
  String _selectedAvatar = kPresetAvatars[0];
  final _collegeController = TextEditingController(text: 'University');
  final _courseController = TextEditingController(text: 'Computer Science');
  int _selectedYear = 2;

  final List<String> _selectedInterests = ['Coding', 'Music & Concerts'];
  final List<String> _selectedHobbies = ['Video Gaming', 'Chess'];
  final List<String> _selectedRelationships = ['Dating'];

  final _bioController = TextEditingController();
  final _ageController = TextEditingController(text: '20');

  bool _isLoading = false;
  String? _errorMessage;
  String? _registrationToken;
  String? _verifiedEmail;
  String? _verifiedUsername;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your full name');
        return false;
      }
      if (_usernameController.text.trim().length < 3) {
        setState(
            () => _errorMessage = 'Username must be at least 3 characters');
        return false;
      }
      if (!RegExp(r'^[a-zA-Z0-9_]{3,25}$')
          .hasMatch(_usernameController.text.trim())) {
        setState(() => _errorMessage =
            'Username can use only letters, numbers, and underscore (_).');
        return false;
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_emailController.text.trim())) {
        setState(() => _errorMessage = 'Please enter a valid email address');
        return false;
      }
      if (_passwordController.text.length < 6) {
        setState(
            () => _errorMessage = 'Password must be at least 6 characters');
        return false;
      }
    } else if (_currentStep == 2) {
      if (_collegeController.text.trim().isEmpty) {
        setState(() =>
            _errorMessage = 'Please enter your college or university name');
        return false;
      }
      if (_courseController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your course or major');
        return false;
      }
    }
    return true;
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep == 0) {
      final currentEmail = _emailController.text.trim().toLowerCase();
      final currentUsername = _usernameController.text.trim().toLowerCase();
      if (_registrationToken != null &&
          _verifiedEmail == currentEmail &&
          _verifiedUsername == currentUsername) {
        setState(() => _currentStep = 1);
        return;
      }
      _registrationToken = null;
      await _verifyFirstStepEmail();
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _handleRegister();
    }
  }

  Future<void> _verifyFirstStepEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response =
          await ApiClient().post(ApiEndpoints.startRegistration, data: {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      if (response.data['success'] != true) {
        setState(() => _errorMessage =
            response.data['message'] ?? 'Unable to send a verification code.');
        return;
      }
      if (!mounted) return;
      final token = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
              email: _emailController.text.trim(), registrationFlow: true)));
      if (token != null && mounted) {
        setState(() {
          _registrationToken = token;
          _verifiedEmail = _emailController.text.trim().toLowerCase();
          _verifiedUsername = _usernameController.text.trim().toLowerCase();
          _currentStep = 1;
        });
      } else if (mounted) {
        // User clicked Back from verification screen without completing
        setState(() {
          _registrationToken = null;
        });
      }
    } on DioException catch (error) {
      final data = error.response?.data;
      if (mounted) {
        setState(() => _errorMessage = data is Map
            ? (data['message'] ?? 'Unable to send a verification code.')
            : 'Unable to connect to server. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ageVal = int.tryParse(_ageController.text.trim()) ?? 20;

    try {
      final res = await ApiClient().post(ApiEndpoints.register, data: {
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'profilePhoto': _selectedAvatar,
        'college': _collegeController.text.trim(),
        'course': _courseController.text.trim(),
        'year': _selectedYear,
        'age': ageVal,
        'interests': _selectedInterests,
        'hobbies': _selectedHobbies,
        'relationshipPreferences': _selectedRelationships,
        'bio': _bioController.text.trim(),
        'registrationToken': _registrationToken,
      });

      if (res.data['success'] == true) {
        final token = res.data['data']['token'];
        final userId = res.data['data']['user']['id'];
        if (token is! String || userId == null) {
          setState(() => _errorMessage =
              'Account was created but sign-in could not be completed. Please sign in.');
          return;
        }
        await TokenStorage.saveToken(token);
        await TokenStorage.saveUserId(userId.toString());
        await SocketService().connect();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainBottomNav()),
              (_) => false);
        }
      } else {
        setState(
            () => _errorMessage = res.data['message'] ?? 'Registration failed');
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.data is Map &&
          dioErr.response?.data['message'] != null) {
        final data = Map<String, dynamic>.from(dioErr.response!.data);
        final errors = data['errors'];
        final fieldError =
            errors is List && errors.isNotEmpty && errors.first is Map
                ? errors.first['message']
                : null;
        setState(() => _errorMessage =
            fieldError is String ? fieldError : (data['message'] as String));
      } else if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
        setState(
            () => _errorMessage = 'Connection timeout connecting to server.');
      } else {
        setState(() =>
            _errorMessage = 'Unable to connect to server. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prevStep,
        ),
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Dynamic Step Content
              if (_currentStep == 0) _buildStep1Credentials(isDark),
              if (_currentStep == 1) _buildStep2Avatar(isDark),
              if (_currentStep == 2) _buildStep3Academics(isDark),
              if (_currentStep == 3) _buildStep4InterestsHobbies(isDark),
              if (_currentStep == 4) _buildStep5Bio(isDark),

              const SizedBox(height: AppSpacing.xxl),

              // Navigation Buttons
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      title: _currentStep == _totalSteps - 1
                          ? 'Complete & Join MatchUp'
                          : 'Next Step',
                      isLoading: _isLoading,
                      onPressed: _nextStep,
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

  // ==========================================
  // STEP 1: CREDENTIALS
  // ==========================================
  Widget _buildStep1Credentials(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Account', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Create your MatchUp profile and verify your email address.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'Full Name',
          hint: 'e.g. Alex Morgan',
          controller: _nameController,
          prefixIcon: const Icon(Icons.person_outline),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Campus Username',
          hint: 'e.g. alex_m',
          controller: _usernameController,
          prefixIcon: const Icon(Icons.alternate_email),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Email address',
          hint: 'e.g. alex@gmail.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Password',
          hint: 'Minimum 6 characters',
          controller: _passwordController,
          obscureText: true,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: AVATAR SELECTION
  // ==========================================
  Widget _buildStep2Avatar(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick Your Avatar', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose a photo or preset avatar that best represents you.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: AvatarImage(url: _selectedAvatar, radius: 56),
              ),
              if (_isUploadingAvatar)
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.45),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Predefined Avatars', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kPresetAvatars.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (ctx, index) {
            final url = kPresetAvatars[index];
            final isSelected = _selectedAvatar == url;
            return GestureDetector(
              onTap: () => setState(() => _selectedAvatar = url),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: AvatarImage(url: url, radius: 28),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(_isUploadingAvatar ? 'Uploading image...' : 'Upload your own image'),
            onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: COLLEGE & ACADEMICS
  // ==========================================
  Widget _buildStep3Academics(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('University & Course', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Help other students on campus discover and connect with you.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'College / University Name',
          hint: 'e.g. Stanford University',
          controller: _collegeController,
          prefixIcon: const Icon(Icons.account_balance_outlined),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Course / Major',
          hint: 'e.g. Computer Science & Eng.',
          controller: _courseController,
          prefixIcon: const Icon(Icons.school_outlined),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Current Academic Year', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [1, 2, 3, 4].map((yr) {
            final isSelected = _selectedYear == yr;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('Year $yr'),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedYear = yr);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: INTERESTS & HOBBIES
  // ==========================================
  Widget _buildStep4InterestsHobbies(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interests & Hobbies', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select topics and hobbies you are passionate about.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Academic & Professional Interests',
            style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
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
        Text('Personal Hobbies', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.sm),
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
      ],
    );
  }

  // ==========================================
  // STEP 5: BIO & AGE
  // ==========================================
  Widget _buildStep5Bio(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Almost Done!', style: AppTypography.displayMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add a short bio and your age to complete your campus card.',
          style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('What are you looking for?', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select one or more relationship types to help us find compatible connections.',
          style: AppTypography.bodySmall.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Age',
          hint: '20',
          controller: _ageController,
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.cake_outlined),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Bio / About You',
          hint:
              'Share what you like doing, your campus goals, or favorite spots...',
          controller: _bioController,
          maxLines: 4,
        ),
      ],
    );
  }

  bool _isUploadingAvatar = false;

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
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
      });

      final res = await ApiClient().post(ApiEndpoints.uploadAvatar, data: formData);

      if (res.data is Map && res.data['success'] == true) {
        final uploadedUrl = res.data['data']?['url'] ?? res.data['url'];
        if (uploadedUrl != null && mounted) {
          setState(() {
            _selectedAvatar = uploadedUrl;
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
          const SnackBar(content: Text('Failed to upload image. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }
}

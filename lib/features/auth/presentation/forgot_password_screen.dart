import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _resetToken;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _extractErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'];
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Server timed out. Please check your network connection.';
      }
    }
    return fallback;
  }

  // Step 1: Send OTP to email
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );

      if (res.data['success'] == true) {
        _startCooldownTimer();
        setState(() {
          _currentStep = 2;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'A 6-digit verification code has been sent to $email.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Failed to send reset code.');
      }
    } catch (e) {
      setState(() => _errorMessage = _extractErrorMessage(e, 'Failed to send reset code. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Step 2: Verify OTP
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6 || int.tryParse(otp) == null) {
      setState(() => _errorMessage = 'Please enter the 6-digit code sent to your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post(
        ApiEndpoints.verifyResetOtp,
        data: {
          'email': _emailController.text.trim(),
          'otp': otp,
        },
      );

      if (res.data['success'] == true) {
        _resetToken = res.data['data']?['resetToken'];
        setState(() {
          _currentStep = 3;
        });
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Invalid verification code.');
      }
    } catch (e) {
      setState(() => _errorMessage = _extractErrorMessage(e, 'Invalid or expired verification code.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Resend OTP
  Future<void> _handleResendOtp() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post(
        ApiEndpoints.forgotPassword,
        data: {'email': _emailController.text.trim()},
      );

      if (res.data['success'] == true) {
        _startCooldownTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new verification code has been dispatched.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Failed to resend code.');
      }
    } catch (e) {
      setState(() => _errorMessage = _extractErrorMessage(e, 'Failed to resend code. Please try again.'));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // Step 3: Reset password
  Future<void> _handleResetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters long.');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match. Please re-check.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post(
        ApiEndpoints.resetPassword,
        data: {
          'resetToken': _resetToken,
          'token': _resetToken,
          'newPassword': password,
        },
      );

      if (res.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password has been reset successfully! Please sign in with your new password.'),
              backgroundColor: AppColors.likeGreen,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop(); // Back to login
        }
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Failed to reset password.');
      }
    } catch (e) {
      setState(() => _errorMessage = _extractErrorMessage(e, 'Failed to reset password.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator
                  Row(
                    children: [
                      _buildStepBadge(1, 'Email', _currentStep >= 1),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 2 ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      _buildStepBadge(2, 'Verify', _currentStep >= 2),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 3 ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      _buildStepBadge(3, 'Password', _currentStep >= 3),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Error banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.skipRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.skipRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.skipRed, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.skipRed),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // STEP 1: Enter email
                  if (_currentStep == 1) ...[
                    Text(
                      'Forgot Your Password?',
                      style: AppTypography.displayMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Enter your registered student email address. We will send you a 6-digit verification code.',
                      style: AppTypography.bodyLarge.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email address',
                      hint: 'you@university.edu',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        title: 'Send Verification Code',
                        isLoading: _isLoading,
                        onPressed: _handleSendOtp,
                      ),
                    ),
                  ],

                  // STEP 2: Enter OTP
                  if (_currentStep == 2) ...[
                    Text(
                      'Enter Verification Code',
                      style: AppTypography.displayMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'We have sent a 6-digit code to ${_emailController.text.trim()}. The code expires in 10 minutes.',
                      style: AppTypography.bodyLarge.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(letterSpacing: 10, fontSize: 26, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: '6-digit code',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        title: 'Verify Code',
                        isLoading: _isLoading,
                        onPressed: _handleVerifyOtp,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed: _resendCooldown > 0 || _isResending ? null : _handleResendOtp,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Resend code in ${_resendCooldown}s'
                              : (_isResending ? 'Sending...' : 'Resend Code'),
                          style: TextStyle(
                            color: _resendCooldown > 0 ? Colors.grey : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // STEP 3: Enter new password
                  if (_currentStep == 3) ...[
                    Text(
                      'Create New Password',
                      style: AppTypography.displayMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Choose a strong password with at least 6 characters.',
                      style: AppTypography.bodyLarge.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      controller: _passwordController,
                      label: 'New Password',
                      hint: '••••••••',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      hint: '••••••••',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        title: 'Reset Password',
                        isLoading: _isLoading,
                        onPressed: _handleResetPassword,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBadge(int step, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppColors.primary : Colors.grey.shade300,
          child: Text(
            '$step',
            style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppColors.primary : Colors.grey,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

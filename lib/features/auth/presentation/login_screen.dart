import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../../navigation/main_bottom_nav.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post(ApiEndpoints.login, data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      if (res.data['success'] == true) {
        final token = res.data['data']['token'];
        final userId = res.data['data']['user']['id'];

        await TokenStorage.saveToken(token);
        await TokenStorage.saveUserId(userId);

        // Ensure real-time socket connects with new credentials
        await SocketService().connect();

        final reward = res.data['data']['reward'];

        if (mounted) {
          if (res.data['data']['rewardReceived'] == true) {
            await _showDailyReward(reward?['points'] ?? 20);
          }
          if (mounted) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainBottomNav()));
          }
        }
      } else {
        setState(() => _errorMessage = res.data['message'] ?? 'Login failed');
      }
    } on DioException catch (dioErr) {
      if (dioErr.response?.data is Map &&
          dioErr.response?.data['errorCode'] == 'EMAIL_NOT_VERIFIED' &&
          mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                VerifyEmailScreen(email: _emailController.text.trim())));
        return;
      }
      if (dioErr.response?.data is Map &&
          dioErr.response?.data['message'] != null) {
        setState(() => _errorMessage = dioErr.response?.data['message']);
      } else if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout) {
        setState(() => _errorMessage =
            'Connection timeout. Please ensure the backend server is running on port 5000.');
      } else {
        setState(() =>
            _errorMessage = 'Unable to connect to server. Please try again.');
      }
    } catch (e) {
      setState(() =>
          _errorMessage = 'Unable to connect to server. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDailyReward(int points) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
            icon: const Icon(Icons.card_giftcard,
                color: AppColors.warning, size: 42),
            title: const Text('Daily Reward'),
            content: Text('+$points Points\n\nWelcome back to MatchUp!',
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome!'))
            ],
          ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              // App Branding
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: AppColors.heartGradient,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'MatchUp',
                    style: AppTypography.displayMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Connect. Match. Belong.',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.hero),

              Text(
                'Welcome Back',
                style: AppTypography.displayMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Sign in with your verified email address',
                style: AppTypography.bodyLarge.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.skipRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border:
                        Border.all(color: AppColors.skipRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.skipRed, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.skipRed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              AppTextField(
                controller: _emailController,
                label: 'Email address',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _passwordController,
                label: 'Password',
                hint: '••••••••',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
              ),
              const SizedBox(height: AppSpacing.xs),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              SizedBox(
                width: double.infinity,
                child: AppButton(
                  title: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      children: const [
                        TextSpan(text: "New student on campus? "),
                        TextSpan(
                          text: 'Create Account',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

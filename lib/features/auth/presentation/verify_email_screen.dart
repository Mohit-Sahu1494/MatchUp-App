import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final bool registrationFlow;
  const VerifyEmailScreen(
      {super.key, required this.email, this.registrationFlow = false});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otp = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is DioException)
      return error.response?.data is Map
          ? (error.response?.data['message'] ??
              'Unable to complete verification.')
          : 'Unable to connect to server. Please try again.';
    return 'Unable to complete verification.';
  }

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient().post(
          widget.registrationFlow
              ? ApiEndpoints.verifyRegistrationOtp
              : ApiEndpoints.verifyEmail,
          data: {'email': widget.email, 'otp': _otp.text.trim()});
      if (res.data['success'] == true && mounted) {
        if (widget.registrationFlow) {
          Navigator.of(context).pop(res.data['data']['registrationToken']);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Email verified. You can now sign in.')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final res = await ApiClient().post(
          widget.registrationFlow
              ? ApiEndpoints.resendRegistrationOtp
              : ApiEndpoints.resendOtp,
          data: {'email': widget.email});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Code sent.')));
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verify email')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.mark_email_read_outlined,
                                size: 64, color: AppColors.primary),
                            const SizedBox(height: AppSpacing.lg),
                            const Text('Verify your email',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                                'We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.xl),
                            TextField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    letterSpacing: 8, fontSize: 24),
                                decoration: const InputDecoration(
                                    labelText: 'Verification code',
                                    border: OutlineInputBorder())),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_error!,
                                      textAlign: TextAlign.center,
                                      style:
                                          const TextStyle(color: Colors.red))),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                                title: 'Verify email',
                                isLoading: _loading,
                                onPressed: _verify),
                            TextButton(
                                onPressed: _resending ? null : _resend,
                                child: Text(
                                    _resending ? 'Sending…' : 'Resend code')),
                          ]),
                    )))),
      );
}

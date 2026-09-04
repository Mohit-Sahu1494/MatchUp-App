import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

class CreateConfessionScreen extends StatefulWidget {
  const CreateConfessionScreen({super.key});

  @override
  State<CreateConfessionScreen> createState() => _CreateConfessionScreenState();
}

class _CreateConfessionScreenState extends State<CreateConfessionScreen> {
  final _textController = TextEditingController();
  bool _isAnonymous = true;
  String _selectedCategory = 'Campus Life';
  bool _isPosting = false;

  final List<String> _categories = [
    'Campus Life',
    'Crush & Dating',
    'Academics & Exams',
    'Professors & Classes',
    'Dorm Life',
    'General',
  ];

  Future<void> _postConfession() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final res = await ApiClient().post(ApiEndpoints.confessions, data: {
        'text': text,
        'isAnonymous': _isAnonymous,
        'category': _selectedCategory,
      });

      if (res.data['success'] == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post. Rate limit: max 5 every 10 min.')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Confession')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share Anonymously or Publicly', style: AppTypography.displayMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Confessions are moderated for campus safety. Anonymous posts never expose your name or student ID.',
                style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Anonymous Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text('Post Anonymously 🎭'),
                subtitle: const Text('Your profile and identity will be hidden'),
                value: _isAnonymous,
                onChanged: (val) => setState(() => _isAnonymous = val),
              ),
              const SizedBox(height: AppSpacing.md),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              TextField(
                controller: _textController,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: 'What is on your mind? Spill the tea...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  filled: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: AppButton(
                  title: 'Publish Confession',
                  isLoading: _isPosting,
                  onPressed: _postConfession,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

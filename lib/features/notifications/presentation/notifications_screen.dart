import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiClient().get(ApiEndpoints.notifications);
      if (res.data is Map && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _notifications =
              list.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = res.data is Map
              ? (res.data['message'] ?? 'Unable to load notifications.')
              : 'Unable to load notifications.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _errorMessage = 'Unable to connect to server. Please try again.';
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _fetchNotifications),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                            onPressed: _fetchNotifications,
                            child: const Text('Retry'))
                      ])))
              : _notifications.isEmpty
                  ? EmptyState(
                      icon: Icons.notifications_none,
                      title: 'No Notifications Yet',
                      description:
                          'When students match with you, send gifts, or like your confessions, you will see it here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final n = _notifications[index];
                          return ListTile(
                            leading: _buildIcon(n['type']),
                            title: Text(n['title'] ?? 'Alert',
                                style: AppTypography.titleMedium),
                            subtitle: Text(n['body'] ?? '',
                                style: AppTypography.bodyMedium),
                            trailing: Text(
                              n['createdAt'] != null
                                  ? DateFormat('hh:mm a')
                                      .format(DateTime.parse(n['createdAt']))
                                  : '',
                              style: AppTypography.labelSmall
                                  .copyWith(color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildIcon(String? type) {
    switch (type) {
      case 'match':
        return const CircleAvatar(
            backgroundColor: AppColors.secondary,
            child: Icon(Icons.favorite, color: Colors.white));
      case 'gift':
        return const CircleAvatar(
            backgroundColor: AppColors.warning,
            child: Icon(Icons.card_giftcard, color: Colors.white));
      case 'call':
        return const CircleAvatar(
            backgroundColor: AppColors.accent,
            child: Icon(Icons.videocam, color: Colors.white));
      default:
        return const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(Icons.notifications, color: Colors.white));
    }
  }
}

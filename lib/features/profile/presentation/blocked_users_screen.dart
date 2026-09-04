import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_image.dart';
import '../../../core/widgets/empty_state.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blockedList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient().get('/safety/blocked');
      if (res.data['success'] == true) {
        setState(() {
          _blockedList = res.data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String blockId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient().delete('/safety/block/$blockId');
      if (res.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unblocked $userName')),
          );
        }
        _fetchBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedList.isEmpty
              ? const EmptyState(
                  icon: Icons.block,
                  title: 'No Blocked Users',
                  description: 'You haven\'t blocked any users. Blocked users cannot see your profile or message you.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _blockedList.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final item = _blockedList[index];
                    final blockedUser = item['blockedId'] ?? {};
                    final profile = item['profile'] ?? {};
                    final name = profile['name'] ?? blockedUser['email'] ?? 'User';
                    final photo = profile['profilePhoto'];
                    final blockId = item['_id'] ?? item['id'] ?? '';

                    return ListTile(
                      leading: AvatarImage(url: photo, radius: 22),
                      title: Text(name, style: AppTypography.titleMedium),
                      subtitle: Text(
                        'Blocked on ${item['createdAt'] != null ? item['createdAt'].toString().split('T').first : 'recently'}',
                        style: AppTypography.labelSmall,
                      ),
                      trailing: TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                        onPressed: () => _unblockUser(blockId, name),
                        child: const Text('Unblock'),
                      ),
                    );
                  },
                ),
    );
  }
}

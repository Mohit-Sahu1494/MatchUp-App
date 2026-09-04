import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/gift_model.dart';

class GiftModalSheet extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final Function(GiftModel)? onGiftSent;

  const GiftModalSheet({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.onGiftSent,
  });

  static void show(
    BuildContext context, {
    required String receiverId,
    required String receiverName,
    Function(GiftModel)? onGiftSent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => GiftModalSheet(
        receiverId: receiverId,
        receiverName: receiverName,
        onGiftSent: onGiftSent,
      ),
    );
  }

  @override
  State<GiftModalSheet> createState() => _GiftModalSheetState();
}

class _GiftModalSheetState extends State<GiftModalSheet> {
  List<GiftModel> _gifts = [];
  bool _isLoading = true;
  String? _selectedCode;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchGifts();
  }

  Future<void> _fetchGifts() async {
    try {
      final res = await ApiClient().get(ApiEndpoints.gifts);
      if (res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _gifts = list.map((g) => GiftModel.fromJson(g)).toList();
          if (_gifts.isNotEmpty) _selectedCode = _gifts.first.code;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSelectedGift() async {
    if (_selectedCode == null) return;
    setState(() => _isSending = true);

    try {
      final res = await ApiClient().post(ApiEndpoints.sendGift, data: {
        'receiverId': widget.receiverId,
        'giftCode': _selectedCode,
        'message': 'Sent you a campus gift!',
      });

      if (res.data['success'] == true) {
        final selectedGift = _gifts.firstWhere((g) => g.code == _selectedCode);
        widget.onGiftSent?.call(selectedGift);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.accent,
            content: Text(
                '${selectedGift.icon} ${selectedGift.name} sent to ${widget.receiverName}!'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to send gift. Check credit balance.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                      child: Text('Send Gift',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Surprise ${widget.receiverName} and boost their campus ranking',
                style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _gifts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width < 360 ? 2 : 3,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (ctx, index) {
                    final gift = _gifts[index];
                    final isSelected = _selectedCode == gift.code;

                    return InkWell(
                      onTap: () => setState(() => _selectedCode = gift.code),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.12)
                              : null,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(gift.icon,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(
                              gift.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${gift.pointValue} pts',
                              style: AppTypography.labelSmall
                                  .copyWith(color: AppColors.warning),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: _isSending ? null : _sendSelectedGift,
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Gift Now',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

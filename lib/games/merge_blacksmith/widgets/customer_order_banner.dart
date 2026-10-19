import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/blacksmith_item.dart';
import '../models/customer_order.dart';

class CustomerOrderBanner extends StatelessWidget {
  final CustomerOrder? order;
  final void Function(int slotIndex) onFulfill;

  const CustomerOrderBanner({
    super.key,
    required this.order,
    required this.onFulfill,
  });

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return const SizedBox.shrink();
    }

    final targetItem = BlacksmithItem.create(order!.targetLevel);

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        onFulfill(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isHovered
                ? AppTheme.mintGreen.withValues(alpha: 0.15)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHovered ? AppTheme.mintGreen : AppTheme.sunnyYellow,
              width: isHovered ? 3.5 : 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? AppTheme.mintGreen.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: isHovered ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Customer Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.lightBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.sunnyYellow, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  order!.avatarEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              // Customer & Request Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order!.customerName,
                      style: AppTheme.headingFont.copyWith(
                        fontSize: 15,
                        color: AppTheme.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Wants: ',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${targetItem.emoji} ${targetItem.name}',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: targetItem.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: targetItem.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lv ${order!.targetLevel}',
                              style: AppTheme.bodyFont.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Reward badge / Drop target indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isHovered ? AppTheme.mintGreen : AppTheme.sunnyYellow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isHovered ? 'DROP!' : '+${order!.rewardScore}',
                      style: AppTheme.headingFont.copyWith(
                        fontSize: 14,
                        color: isHovered ? Colors.white : AppTheme.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isHovered ? '✨' : 'PTS',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isHovered ? Colors.white : AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

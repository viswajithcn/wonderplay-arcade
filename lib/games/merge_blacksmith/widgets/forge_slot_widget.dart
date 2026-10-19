import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/blacksmith_item.dart';

class ForgeSlotWidget extends StatelessWidget {
  final int slotIndex;
  final BlacksmithItem? item;
  final void Function(int fromIndex, int toIndex) onMoveOrMerge;

  const ForgeSlotWidget({
    super.key,
    required this.slotIndex,
    required this.item,
    required this.onMoveOrMerge,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != slotIndex,
      onAcceptWithDetails: (details) {
        onMoveOrMerge(details.data, slotIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovered
                ? AppTheme.sunnyYellow.withValues(alpha: 0.3)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered
                  ? AppTheme.amberOrange
                  : Colors.blueGrey.shade100,
              width: isHovered ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? AppTheme.amberOrange.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isHovered ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: item != null ? _buildDraggableItem(context, item!) : _buildEmptySlot(),
        );
      },
    );
  }

  Widget _buildEmptySlot() {
    return Center(
      child: Icon(
        Icons.add_rounded,
        size: 24,
        color: Colors.blueGrey.shade200,
      ),
    );
  }

  Widget _buildDraggableItem(BuildContext context, BlacksmithItem currentItem) {
    return Draggable<int>(
      data: slotIndex,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 72,
          height: 72,
          child: _ItemCard(item: currentItem, isFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _ItemCard(item: currentItem),
      ),
      child: _ItemCard(item: currentItem),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final BlacksmithItem item;
  final bool isFeedback;

  const _ItemCard({
    required this.item,
    this.isFeedback = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [item.color, item.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isFeedback
                ? Colors.black.withValues(alpha: 0.3)
                : item.color.withValues(alpha: 0.4),
            blurRadius: isFeedback ? 12 : 5,
            offset: Offset(0, isFeedback ? 6 : 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji / Icon
            Text(
              item.emoji,
              style: TextStyle(
                fontSize: isFeedback ? 26 : 22,
              ),
            ),
            const SizedBox(height: 2),
            // Level Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lv ${item.level}',
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
    );
  }
}

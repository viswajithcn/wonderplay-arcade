import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/mini_game_model.dart';
import '../../../shared/widgets/game_over_dialog.dart';
import '../../../shared/widgets/kid_button.dart';
import '../../../shared/widgets/victory_dialog.dart';
import '../controllers/merge_blacksmith_controller.dart';
import '../widgets/customer_order_banner.dart';
import '../widgets/forge_slot_widget.dart';

class MergeBlacksmithScreen extends StatefulWidget {
  final GameStorage? storage;
  final GameDifficulty difficulty;
  final MergeBlacksmithController? controller;
  final void Function(int score)? onGameOver;
  final VoidCallback? onExit;

  const MergeBlacksmithScreen({
    super.key,
    this.storage,
    this.difficulty = GameDifficulty.easy,
    this.controller,
    this.onGameOver,
    this.onExit,
  });

  static Widget builder(
    BuildContext context,
    GameDifficulty difficulty, {
    GameStorage? storage,
  }) {
    return MergeBlacksmithScreen(
      storage: storage,
      difficulty: difficulty,
    );
  }

  @override
  State<MergeBlacksmithScreen> createState() => _MergeBlacksmithScreenState();
}

class _MergeBlacksmithScreenState extends State<MergeBlacksmithScreen> {
  late final MergeBlacksmithController _controller;
  late final bool _ownsController;
  final AudioController _audio = AudioController();
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = MergeBlacksmithController(
        storage: widget.storage,
      );
      _ownsController = true;
    }

    _controller.addListener(_onControllerUpdate);
    _audio.startBgm();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (_controller.isGameOver && !_dialogShowing) {
      _dialogShowing = true;
      _showEndGameDialog();
    } else {
      setState(() {});
    }
  }

  void _showEndGameDialog() {
    widget.onGameOver?.call(_controller.score);

    if (_controller.ordersFulfilled > 0) {
      VictoryDialog.show(
        context: context,
        result: GameResult(
          score: _controller.score,
          totalQuestions: _controller.ordersFulfilled + 1,
          correctAnswers: _controller.ordersFulfilled,
          stars: _controller.stars,
          difficulty: widget.difficulty,
        ),
        onPlayAgain: () {
          _dialogShowing = false;
          _controller.reset();
        },
        onExit: () {
          _dialogShowing = false;
          widget.onExit?.call();
          Navigator.of(context).maybePop();
        },
      );
    } else {
      GameOverDialog.show(
        context: context,
        score: _controller.score,
        questionsAnswered: _controller.ordersFulfilled,
        onRetry: () {
          _dialogShowing = false;
          _controller.reset();
        },
        onExit: () {
          _dialogShowing = false;
          widget.onExit?.call();
          Navigator.of(context).maybePop();
        },
      );
    }
  }

  void _showHelpRecipeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Forge Recipe Book 📖',
                  style: AppTheme.headingFont.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 12),
                _recipeRow('🧱 Lv 1 Iron Ingot', '🧱 Lv 1', '🗡️ Lv 2 Bronze Dagger'),
                const Divider(),
                _recipeRow('🗡️ Lv 2 Bronze Dagger', '🗡️ Lv 2', '⚔️ Lv 3 Iron Shortsword'),
                const Divider(),
                _recipeRow('⚔️ Lv 3 Iron Shortsword', '⚔️ Lv 3', '🪓 Lv 4 Steel Battleaxe'),
                const Divider(),
                _recipeRow('🪓 Lv 4 Steel Battleaxe', '🪓 Lv 4', '✨ Lv 5 Enchanted Blade'),
                const SizedBox(height: 16),
                KidButton(
                  color: AppTheme.mintGreen,
                  minWidth: 120,
                  height: 44,
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Got It!',
                    style: AppTheme.bodyFont.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recipeRow(String itemA, String itemB, String result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$itemA + $itemB',
              style: AppTheme.bodyFont.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blueGrey),
          ),
          Expanded(
            child: Text(
              result,
              style: AppTheme.bodyFont.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            _buildHeader(),

            // Customer Order Banner
            CustomerOrderBanner(
              order: _controller.currentOrder,
              onFulfill: (slotIndex) {
                _controller.fulfillOrder(slotIndex);
              },
            ),

            // Feedback Message Bar
            if (_controller.feedbackMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue, width: 1),
                ),
                child: Text(
                  _controller.feedbackMessage!,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Forge Grid (4x5)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(MergeBlacksmithController.rows, (rowIndex) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(MergeBlacksmithController.cols, (colIndex) {
                                final index = rowIndex * MergeBlacksmithController.cols + colIndex;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: ForgeSlotWidget(
                                      slotIndex: index,
                                      item: _controller.slots[index],
                                      onMoveOrMerge: (fromIndex, toIndex) {
                                        _controller.mergeOrMove(fromIndex, toIndex);
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Controls Bar
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: () {
              widget.onExit?.call();
              Navigator.of(context).maybePop();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkText, size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Merge Blacksmith ⚒️',
                  style: AppTheme.headingFont.copyWith(fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Orders: ${_controller.ordersFulfilled}',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    color: AppTheme.mintGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Score Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sunnyYellow, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.sunnyYellow, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${_controller.score}',
                  style: AppTheme.headingFont.copyWith(
                    fontSize: 16,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Recipe Help Button
          InkWell(
            onTap: _showHelpRecipeSheet,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppTheme.amberOrange, size: 20),
            ),
          ),
          const SizedBox(width: 6),

          // Audio Toggle Button
          InkWell(
            onTap: () {
              if (widget.storage != null) {
                _audio.toggleMasterMute(widget.storage!);
              }
              setState(() {});
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: AppTheme.darkText,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Auto-spawn timer indicator
          Expanded(
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next Ingot in ${_controller.secondsUntilSpawn}s',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (3 - _controller.secondsUntilSpawn) / 3.0,
                          backgroundColor: Colors.blueGrey.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.amberOrange),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Quick Forge Button
          KidButton(
            height: 44,
            minWidth: 110,
            color: AppTheme.amberOrange,
            onPressed: () {
              _controller.spawnItem();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Forge!',
                  style: AppTheme.bodyFont.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

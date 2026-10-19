import 'package:flutter/material.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/parental_gate/parental_gate_dialog.dart';
import '../../core/storage/game_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../games/mini_game_registry.dart';
import '../../models/mini_game_model.dart';
import '../widgets/game_card.dart';

class GameHubScreen extends StatefulWidget {
  final GameStorage storage;

  const GameHubScreen({super.key, required this.storage});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  GameCategory _selectedCategory = GameCategory.all;
  late final AudioController _audio;

  @override
  void initState() {
    super.initState();
    _audio = AudioController();
  }

  void _onCategoryChanged(GameCategory category) {
    _audio.playClick();
    setState(() => _selectedCategory = category);
  }

  void _openParentSettings() async {
    _audio.playClick();
    final verified = await ParentalGateDialog.verify(context);
    if (!verified || !mounted) return;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Row(
            children: [
              const Icon(Icons.settings_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text('Parent Settings', style: AppTheme.headingFont),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.volume_up_rounded, color: AppTheme.mintGreen),
                title: Text('Sound Effects (SFX)', style: AppTheme.bodyFont),
                trailing: Switch(
                  value: _audio.sfxEnabled,
                  onChanged: (val) {
                    setDialogState(() {
                      _audio.setSfxEnabled(val, widget.storage);
                    });
                    setState(() {});
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note_rounded, color: AppTheme.bubblePurple),
                title: Text('Background Music (BGM)', style: AppTheme.bodyFont),
                trailing: Switch(
                  value: _audio.bgmEnabled,
                  onChanged: (val) {
                    setDialogState(() {
                      _audio.setBgmEnabled(val, widget.storage);
                    });
                    setState(() {});
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Kids Mini-Game Studio v1.0.0\nCOPPA & GDPR-K Compliant • Offline Friendly',
                  style: AppTheme.bodyFont.copyWith(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done', style: AppTheme.bodyFont),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGames = MiniGameRegistry.getGames(widget.storage);
    final filteredGames = _selectedCategory == GameCategory.all
        ? allGames
        : allGames.where((g) => g.category == _selectedCategory).toList();

    final totalStars = widget.storage.getTotalStars();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9), // Mint light tint
              Color(0xFFE1F5FE), // Cloud light blue
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top App Bar & Player Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    children: [
                      // Mascot Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.sunnyYellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.amberOrange.withValues(alpha: 0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🦁', style: TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WonderPlay Arcade!',
                              style: AppTheme.titleFont.copyWith(fontSize: 28),
                            ),
                            Text(
                              'Play, Learn & Collect Stars!',
                              style: AppTheme.bodyFont.copyWith(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Star Counter Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.amberOrange, size: 26),
                            const SizedBox(width: 6),
                            Text(
                              '$totalStars',
                              style: AppTheme.headingFont.copyWith(
                                color: AppTheme.darkText,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Master Volume / Audio Quick Toggle
                      ListenableBuilder(
                        listenable: _audio,
                        builder: (context, _) {
                          final isMuted = _audio.isMuted;
                          return IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: isMuted ? Colors.redAccent : AppTheme.deepBlue,
                            ),
                            onPressed: () {
                              _audio.toggleMasterMute(widget.storage);
                            },
                            icon: Icon(
                              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              size: 22,
                            ),
                          );
                        },
                      ),

                      // Parental Settings Gate Button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.deepBlue,
                        ),
                        onPressed: _openParentSettings,
                        icon: const Icon(Icons.settings_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Category Filter Pills
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: GameCategory.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final cat = GameCategory.values[index];
                      final isSelected = cat == _selectedCategory;

                      return ChoiceChip(
                        selected: isSelected,
                        onSelected: (_) => _onCategoryChanged(cat),
                        avatar: Icon(
                          cat.icon,
                          size: 18,
                          color: isSelected ? Colors.white : cat.color,
                        ),
                        label: Text(
                          cat.label,
                          style: AppTheme.bodyFont.copyWith(
                            color: isSelected ? Colors.white : AppTheme.darkText,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        selectedColor: cat.color,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? cat.color : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 18),
              ),

              // 3. Mini Games Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    int crossAxisCount = 1;
                    double childAspectRatio = 1.35;

                    if (width > 800) {
                      crossAxisCount = 3;
                      childAspectRatio = 1.25;
                    } else if (width > 520) {
                      crossAxisCount = 2;
                      childAspectRatio = 1.25;
                    }

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final game = filteredGames[index];
                          return GameCard(
                            game: game,
                            storage: widget.storage,
                            onPlayGame: (difficulty) async {
                              if (game.builder != null) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => game.builder!(ctx, difficulty),
                                  ),
                                );
                                // Refresh total stars on return
                                setState(() {});
                              }
                            },
                          );
                        },
                        childCount: filteredGames.length,
                      ),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

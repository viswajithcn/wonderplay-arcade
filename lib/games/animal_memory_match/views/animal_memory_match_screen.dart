import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/mini_game_model.dart';
import '../../../shared/widgets/game_over_dialog.dart';
import '../../../shared/widgets/hearts_display.dart';
import '../../../shared/widgets/kid_button.dart';
import '../../../shared/widgets/victory_dialog.dart';
import '../models/animal_card_model.dart';
import '../models/memory_level.dart';
import '../widgets/memory_card_widget.dart';

class AnimalMemoryMatchScreen extends StatefulWidget {
  final MemoryLevel level;
  final GameStorage storage;
  final int playerCount;

  const AnimalMemoryMatchScreen({
    super.key,
    required this.level,
    required this.storage,
    this.playerCount = 2,
  });

  @override
  State<AnimalMemoryMatchScreen> createState() => _AnimalMemoryMatchScreenState();
}

class _AnimalMemoryMatchScreenState extends State<AnimalMemoryMatchScreen> {
  final List<AnimalCardModel> _cards = [];
  AnimalCardModel? _firstSelected;
  AnimalCardModel? _secondSelected;
  bool _isProcessing = false;

  int _matchedPairs = 0;
  int _score = 0;
  int _streak = 0;
  late int _hearts;
  String? _encouragementMessage;
  Timer? _encouragementTimer;
  final Set<String> _previouslySeenAnimals = {};

  late List<MemoryPlayer> _players;
  int _currentPlayerIndex = 0;

  int _gameRound = 0;

  bool get _isMultiplayer => widget.playerCount > 1;
  MemoryPlayer get _currentPlayer => _players[_currentPlayerIndex];

  @override
  void initState() {
    super.initState();
    _hearts = widget.level.maxHearts;
    _players = MemoryPlayer.createPlayers(widget.playerCount);
    _setupCards();
    AudioController().startBgm();
  }

  @override
  void dispose() {
    _encouragementTimer?.cancel();
    super.dispose();
  }

  void _setupCards() {
    _cards.clear();
    _previouslySeenAnimals.clear();
    _firstSelected = null;
    _secondSelected = null;
    _matchedPairs = 0;
    _isProcessing = false;
    _currentPlayerIndex = 0;
    _players = MemoryPlayer.createPlayers(widget.playerCount);
    _gameRound++;

    final pool = List<AnimalData>.from(AnimalCardModel.pool)..shuffle();
    final chosenAnimals = pool.take(widget.level.pairsCount).toList();

    int idCounter = 0;
    for (final animal in chosenAnimals) {
      // 2 identical cards per animal
      _cards.add(AnimalCardModel(id: idCounter++, animal: animal));
      _cards.add(AnimalCardModel(id: idCounter++, animal: animal));
    }

    _cards.shuffle();
  }

  void _onCardTapped(AnimalCardModel card) {
    if (_isProcessing || card.isFaceUp || card.isMatched) return;

    AudioController().playClick();

    setState(() {
      card.isFaceUp = true;
    });

    if (_firstSelected == null) {
      _firstSelected = card;
    } else {
      _secondSelected = card;
      _checkMatch();
    }
  }

  void _checkMatch() {
    _isProcessing = true;
    final card1 = _firstSelected!;
    final card2 = _secondSelected!;

    if (card1.animal.name == card2.animal.name) {
      // Match found!
      _previouslySeenAnimals.add(card1.animal.name);
      AudioController().playPop();
      AudioController().playCorrect();

      setState(() {
        card1.isMatched = true;
        card2.isMatched = true;
        if (_isMultiplayer) {
          card1.matchedByPlayer = _currentPlayerIndex;
          card1.matchedPlayerColor = _currentPlayer.color;
          card2.matchedByPlayer = _currentPlayerIndex;
          card2.matchedPlayerColor = _currentPlayer.color;
          _currentPlayer.pairsMatched++;
          _currentPlayer.score += 150 + (_streak * 30);
        }
        _matchedPairs++;
        _streak++;
        _score += 150 + (_streak * 30);
        if (_isMultiplayer) {
          final isLastPair = _matchedPairs >= widget.level.pairsCount;
          _showEncouragement(
            isLastPair
                ? '🎉 ${card1.animal.name} Matched by ${_currentPlayer.name}!'
                : '🎉 ${card1.animal.name} Matched! ${_currentPlayer.name} goes again!',
          );
        } else {
          _showEncouragement('${card1.animal.name} Matched! ${card1.animal.emoji}');
        }
        _firstSelected = null;
        _secondSelected = null;
        _isProcessing = false;
      });

      if (_matchedPairs >= widget.level.pairsCount) {
        Future.delayed(const Duration(milliseconds: 500), _finishGameSuccess);
      }
    } else {
      if (_isMultiplayer) {
        // Pass & Play Multiplayer: No heart loss, turn passes to next player after reveal!
        final nextIndex = (_currentPlayerIndex + 1) % _players.length;
        final nextPlayer = _players[nextIndex];
        setState(() {
          _streak = 0;
          _showEncouragement('No match! Memorize ${card1.animal.emoji} & ${card2.animal.emoji}');
        });

        Future.delayed(const Duration(milliseconds: 850), () {
          if (!mounted) return;
          setState(() {
            card1.isFaceUp = false;
            card2.isFaceUp = false;
            _firstSelected = null;
            _secondSelected = null;
            _currentPlayerIndex = nextIndex;
            _isProcessing = false;
            _showEncouragement('🔄 Pass to ${nextPlayer.name} ${nextPlayer.emoji}!');
          });
        });
      } else {
        // 1P Solo Mode: check if either animal was already seen in a previous turn
        final animal1WasKnown = _previouslySeenAnimals.contains(card1.animal.name);
        final animal2WasKnown = _previouslySeenAnimals.contains(card2.animal.name);
        final isMemoryMistake = animal1WasKnown || animal2WasKnown;

        // Remember both animals for future turns
        _previouslySeenAnimals.add(card1.animal.name);
        _previouslySeenAnimals.add(card2.animal.name);

        if (!isMemoryMistake) {
          // Both animals were opened for the very first time: Free discovery! No heart lost!
          setState(() {
            _showEncouragement('New animals found! Remember them 🔍');
          });
        } else {
          // An animal that was already revealed before was missed: Lose a heart!
          AudioController().playWrong();
          final missedAnimal = animal1WasKnown ? card1.animal.name : card2.animal.name;
          setState(() {
            _streak = 0;
            _hearts--;
            _showEncouragement('Already saw $missedAnimal! Lost a Heart 💔');
          });

          if (_hearts <= 0) {
            _isProcessing = false;
            Future.delayed(const Duration(milliseconds: 500), _triggerGameOver);
            return;
          }
        }

        // Keep cards visible for a moment so the child memorizes them
        Future.delayed(const Duration(milliseconds: 850), () {
          if (!mounted) return;
          setState(() {
            card1.isFaceUp = false;
            card2.isFaceUp = false;
            _firstSelected = null;
            _secondSelected = null;
            _isProcessing = false;
          });
        });
      }
    }
  }

  void _triggerGameOver() {
    GameOverDialog.show(
      context: context,
      score: _score,
      questionsAnswered: _matchedPairs,
      onRetry: () {
        setState(() {
          _hearts = widget.level.maxHearts;
          _score = 0;
          _streak = 0;
          _setupCards();
        });
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _finishGameSuccess() {
    // 3 stars in multiplayer or if >= 75% hearts remain in solo
    int stars = 3;
    if (!_isMultiplayer) {
      stars = 1;
      final heartRatio = _hearts / widget.level.maxHearts;
      if (heartRatio >= 0.75) {
        stars = 3;
      } else if (heartRatio >= 0.5) {
        stars = 2;
      }
    }

    widget.storage.saveLevelResult(
      'animal_memory_match',
      widget.level.number,
      _score,
      stars,
    );

    if (_isMultiplayer) {
      _showMultiplayerWinnerDialog();
      return;
    }

    final result = GameResult(
      score: _score,
      totalQuestions: widget.level.pairsCount,
      correctAnswers: _matchedPairs,
      stars: stars,
      difficulty: GameDifficulty.easy,
    );

    VictoryDialog.show(
      context: context,
      result: result,
      onPlayAgain: () {
        setState(() {
          _hearts = widget.level.maxHearts;
          _score = 0;
          _streak = 0;
          _setupCards();
        });
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showMultiplayerWinnerDialog() {
    AudioController().playCelebrate();
    final sortedPlayers = List<MemoryPlayer>.from(_players)
      ..sort((a, b) => b.pairsMatched.compareTo(a.pairsMatched));
    final topPairs = sortedPlayers.first.pairsMatched;
    final winners = sortedPlayers.where((p) => p.pairsMatched == topPairs).toList();
    final isTie = winners.length > 1;

    const medals = ['🥇', '🥈', '🥉', '🎖️'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isTie ? AppTheme.sunnyYellow : winners.first.color).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isTie ? '🤝' : winners.first.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isTie
                    ? "It's a Tie! 🎉"
                    : '${winners.first.name} Wins! 🏆',
                style: AppTheme.titleFont.copyWith(
                  fontSize: 26,
                  color: isTie ? AppTheme.bubblePurple : winners.first.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                isTie
                    ? '${winners.map((w) => w.name).join(' & ')} matched $topPairs pairs each!'
                    : 'Matched $topPairs of ${widget.level.pairsCount} animal pairs!',
                style: AppTheme.bodyFont.copyWith(fontSize: 13, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Leaderboard list
              ...List.generate(sortedPlayers.length, (idx) {
                final p = sortedPlayers[idx];
                final isWinner = p.pairsMatched == topPairs;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isWinner ? p.color.withValues(alpha: 0.14) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isWinner ? p.color : Colors.grey.shade300,
                      width: isWinner ? 2.5 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(medals[idx.clamp(0, medals.length - 1)], style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(p.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: AppTheme.headingFont.copyWith(
                            fontSize: 16,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${p.pairsMatched} ${p.pairsMatched == 1 ? 'Pair' : 'Pairs'}',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KidButton(
                    minWidth: 110,
                    height: 48,
                    color: Colors.grey.shade300,
                    shadowColor: Colors.grey.shade500,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text('Levels', style: AppTheme.bodyFont),
                  ),
                  const SizedBox(width: 12),
                  KidButton(
                    minWidth: 140,
                    height: 48,
                    color: AppTheme.mintGreen,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      setState(() {
                        _hearts = widget.level.maxHearts;
                        _score = 0;
                        _streak = 0;
                        _setupCards();
                      });
                    },
                    child: Text(
                      'Rematch! 🔄',
                      style: AppTheme.bodyFont.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEncouragement(String msg) {
    _encouragementTimer?.cancel();
    setState(() => _encouragementMessage = msg);
    _encouragementTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _encouragementMessage = null);
    });
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Center(child: Text('Game Paused', style: AppTheme.headingFont)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_filled_rounded, size: 64, color: AppTheme.bubblePurple),
            const SizedBox(height: 16),
            Text('Ready to find more animal pairs?', style: AppTheme.bodyFont, textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          KidButton(
            minWidth: 100,
            height: 48,
            color: Colors.grey.shade300,
            shadowColor: Colors.grey.shade500,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Exit', style: AppTheme.bodyFont),
          ),
          const SizedBox(width: 8),
          KidButton(
            minWidth: 120,
            height: 48,
            color: AppTheme.mintGreen,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Resume', style: AppTheme.bodyFont.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplayerScoreboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          for (final player in _players)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: player.index == _currentPlayerIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: player.index == _currentPlayerIndex
                        ? player.color
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: player.index == _currentPlayerIndex
                      ? [
                          BoxShadow(
                            color: player.color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(player.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _players.length > 2 ? player.shortName : player.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headingFont.copyWith(
                              fontSize: 13,
                              color: player.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${player.pairsMatched} ${player.pairsMatched == 1 ? 'Pair' : 'Pairs'}',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3E5F5), // Soft pastel purple
              Color(0xFFE1BEE7),
              Color(0xFFCE93D8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.bubblePurple,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(38, 38),
                      ),
                      onPressed: _showPauseDialog,
                      icon: const Icon(Icons.pause_rounded, size: 22),
                    ),

                    // Level & Pairs Progress
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        'Lvl ${widget.level.number} • $_matchedPairs/${widget.level.pairsCount}',
                        style: AppTheme.bodyFont.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.bubblePurple,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    if (_isMultiplayer)
                      // Active Player Turn Pill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentPlayer.color,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _currentPlayer.color.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currentPlayer.emoji, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 5),
                            Text(
                              "${_currentPlayer.name}'s Turn",
                              style: AppTheme.headingFont.copyWith(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Solo Mode Hearts Display
                      HeartsDisplay(
                        maxHearts: widget.level.maxHearts,
                        remainingHearts: _hearts,
                      ),

                      // Solo Mode Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.sunnyYellow,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.amberOrange.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$_score',
                              style: AppTheme.headingFont.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Pass & Play Scoreboard Bar
              if (_isMultiplayer) _buildMultiplayerScoreboard(),

              // Fixed-height Message Slot (prevents card grid jumping)
              SizedBox(
                height: 38,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _encouragementMessage != null
                        ? Container(
                            key: ValueKey(_encouragementMessage),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isMultiplayer ? _currentPlayer.color : AppTheme.sunnyYellow,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _encouragementMessage!,
                              style: AppTheme.headingFont.copyWith(
                                color: !_isMultiplayer && _hearts <= 1
                                    ? const Color(0xFFFF1744)
                                    : (_isMultiplayer ? _currentPlayer.color : AppTheme.bubblePurple),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : (_isMultiplayer
                            ? Text(
                                '📱 Pass & Play: ${_currentPlayer.emoji} ${_currentPlayer.name}, tap 2 cards!',
                                style: AppTheme.bodyFont.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.bubblePurple,
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
              ),

              // Card Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.level.gridColumns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return MemoryCardWidget(
                        key: ValueKey('${card.id}_$_gameRound'),
                        card: card,
                        onTap: () => _onCardTapped(card),
                      );
                    },
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

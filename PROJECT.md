# Project: WonderPlay Arcade

## Architecture
- **Framework & Engine**: Flutter 3.32.8 (Dart 3.8.1), Flame 1.35.1 (for Gravity Glitch), AnimationController (for Color Switch Courier & Splash), Flutter Draggable/DragTarget (for Merge Blacksmith).
- **Core Subsystems**:
  - `lib/core/audio/audio_controller.dart`: Centralized singleton for preloaded byte-cache sound effects and BGM.
  - `lib/core/storage/game_storage.dart`: Persistent SharedPreferences storage for stars, level completions, and high scores.
  - `lib/core/theme/app_theme.dart`: Consistent styling and typography using GoogleFonts.
  - `lib/hub/`: Game hub UI, animated splash screen, game card presentation.
  - `lib/games/mini_game_registry.dart`: Catalog registering all active and playable mini-games.
  - `lib/shared/widgets/`: Common UI components (VictoryDialog, GameOverDialog, HeartsDisplay, KidButton).
- **Platform Integration**:
  - Android: `AndroidManifest.xml` (title "WonderPlay Arcade"), mipmap launcher icons (`mdpi` through `xxxhdpi`), Kotlin DSL release build.
  - Web: `web/index.html` (title "WonderPlay Arcade"), `web/manifest.json`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | App Title Branding | Update app title to "WonderPlay Arcade" in MaterialApp, AndroidManifest.xml, web/index.html, and web/manifest.json | M1 | ORIGINAL_REQUEST R1 |
| 2 | Animated Splash Screen | Polished, bouncy animated splash screen displaying "WonderPlay Arcade" with smooth transition to GameHubScreen | M1 | ORIGINAL_REQUEST R1 |
| 3 | Kid-friendly Launcher Icons | Generate & install custom arcade launcher icons for Android (all mipmap densities) and web | M1 | ORIGINAL_REQUEST R1 |
| 4 | Forge 4x5 Grid | 20-slot interactive blacksmith grid for items Lv 1–5 | M2 | ORIGINAL_REQUEST R2 |
| 5 | 3-Second Automatic Spawner | Periodic timer spawning Lv 1 blacksmith items in random empty slots | M2 | ORIGINAL_REQUEST R2 |
| 6 | Draggable/DragTarget Merge | Drag Lv(k) item onto Lv(k) item to merge into Lv(k+1) up to Lv 5; swap/move logic | M2 | ORIGINAL_REQUEST R2 |
| 7 | Customer Orders Banner | Top banner requesting target item levels with direct drag-and-drop delivery | M2 | ORIGINAL_REQUEST R2 |
| 8 | Blacksmith Audio & Storage | Integrate AudioController (pop, correct, celebrate) and GameStorage for stars/levels | M2 | ORIGINAL_REQUEST R2 |
| 9 | FlameGame Base & Runner | Flame engine runner with HasCollisionDetection and TapCallbacks | M3 | ORIGINAL_REQUEST R3 |
| 10 | RectangleHitbox Collision | Precise collision bounds on player and obstacles | M3 | ORIGINAL_REQUEST R3 |
| 11 | Single-Tap Gravity Inversion | Tap to flip vertical gravity between floor and ceiling | M3 | ORIGINAL_REQUEST R3 |
| 12 | Moving Spikes Spawner | Floor and ceiling spikes moving right-to-left with safe clearance | M3 | ORIGINAL_REQUEST R3 |
| 13 | Glitch Lives, Score & Audio | 3-hearts life system, post-hit grace period, AudioController integration, GameOverDialog | M3 | ORIGINAL_REQUEST R3 |
| 14 | Courier AnimationController | 60fps vertical ticker powering downward scrolling gates | M4 | ORIGINAL_REQUEST R4 |
| 15 | 3-Color Cycling Ship | Bottom-center courier drone cycling Red -> Green -> Blue on tap with sound | M4 | ORIGINAL_REQUEST R4 |
| 16 | Downward Laser Gates | Scrolling colored laser gates with geometric accessibility glyphs | M4 | ORIGINAL_REQUEST R4 |
| 17 | Color Match Collision Check | Player Y-crossing collision: match gives +1 score, mismatch triggers game over | M4 | ORIGINAL_REQUEST R4 |
| 18 | Courier Audio & Storage | Integrate AudioController SFX and GameStorage high score / star saves | M4 | ORIGINAL_REQUEST R4 |
| 19 | MiniGameRegistry Integration | Register all 3 new games with cards, badges, and difficulty ratings in MiniGameRegistry | M5 | ORIGINAL_REQUEST R5 |
| 20 | Static Analysis & Test Verification | flutter analyze with 0 errors and 100% flutter test passing suite | M5 | ORIGINAL_REQUEST R5 |
| 21 | Production APK Release Build | Compile release APK via flutter build apk --release at build/app/outputs/flutter-apk/app-release.apk | M5 | ORIGINAL_REQUEST R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Branding, Splash & Icons | Title rebrand across platforms, animated splash screen, Android & web launcher icons, test alignment | none | DONE |
| 2 | M2: Game 1 - Merge Blacksmith | 4x5 forge grid, 3s auto spawner, drag/drop merge Lv1->5, order banner, audio & storage | none | DONE |
| 3 | M3: Game 2 - Gravity Glitch | FlameGame runner, RectangleHitbox, gravity flip, floor/ceiling moving spikes, lives/score, audio & storage | none | DONE |
| 4 | M4: Game 3 - Color Switch Courier | AnimationController vertical runner, 3-color cycling ship, laser gates, collision matching, audio & storage | none | DONE |
| 5 | M5: Integration, Verification & APK | MiniGameRegistry entries for all 3 games, 100% test pass, flutter analyze 0 issues, production APK build | M1, M2, M3, M4 | IN_PROGRESS |

## Interface Contracts
### App Entry & Splash
- `KidsGamesApp`: MaterialApp with `home: SplashScreen(storage: storage)`.
- `SplashScreen`: State-driven or timer-driven (1.8s) navigation to `GameHubScreen(storage: storage)`.
- Hub Title: Displays "WonderPlay Arcade" in header; `test/widget_test.dart` asserts "WonderPlay Arcade".

### Game Contracts with Platform
All 3 games must adhere to the standard interface:
- **Registry Constructor / Builder**:
  ```dart
  Widget Function(BuildContext context, GameDifficulty difficulty)
  ```
- **Audio Integration**:
  - Use `AudioController()` singleton (`playPop()`, `playCorrect()`, `playWrong()`, `playCelebrate()`, `playClick()`).
- **Storage Integration**:
  - `storage.saveLevelResult(gameId, level, score, stars)` and/or `storage.saveGameResult(gameId, difficultyString, score, stars)`.
  - Level 1 star rating saved so `storage.getLevelStars(gameId, 1)` reflects gold stars on the Hub card.
- **Game Over & Victory UI**:
  - Invoke `GameOverDialog.show(context: ..., score: ..., ...)` or `VictoryDialog.show(context: ..., result: ..., ...)`.

## Code Layout
- `android/app/src/main/AndroidManifest.xml`: Android title and icon configuration
- `android/app/src/main/res/mipmap-*/`: Android launcher icons
- `web/index.html`, `web/manifest.json`: Web title and icon configuration
- `lib/main.dart`: Root widget and app configuration
- `lib/splash/views/splash_screen.dart`: Animated bouncy splash screen
- `lib/hub/views/game_hub_screen.dart`: Hub header "WonderPlay Arcade"
- `lib/games/merge_blacksmith/`:
  - `models/blacksmith_item.dart`
  - `models/customer_order.dart`
  - `controllers/merge_blacksmith_controller.dart`
  - `views/merge_blacksmith_screen.dart`
  - `widgets/forge_slot_widget.dart`
  - `widgets/customer_order_banner.dart`
- `lib/games/gravity_glitch/`:
  - `game/gravity_glitch_game.dart`
  - `components/glitch_player.dart`
  - `components/spike_obstacle.dart`
  - `components/spike_spawner.dart`
  - `views/gravity_glitch_screen.dart`
- `lib/games/color_switch_courier/`:
  - `models/courier_color.dart`
  - `models/laser_gate.dart`
  - `views/color_switch_courier_screen.dart`
  - `widgets/courier_ship_widget.dart`
  - `widgets/laser_gate_widget.dart`
- `lib/games/mini_game_registry.dart`: Registration of the 3 new games
- `test/`:
  - `test/widget_test.dart`: Updated baseline hub test
  - `test/merge_blacksmith_test.dart`: Unit tests for Merge Blacksmith
  - `test/gravity_glitch_test.dart`: Unit tests for Gravity Glitch
  - `test/color_switch_courier_test.dart`: Unit tests for Color Switch Courier
  - `test/e2e/`: E2E opaque-box test suite

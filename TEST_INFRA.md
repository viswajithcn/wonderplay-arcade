# Test Infrastructure & Specification: WonderPlay Arcade

## 1. Test Philosophy & Principles

### 1.1 Opaque-Box & Requirement-Driven Testing
All tests in the WonderPlay Arcade test suite operate strictly on an **opaque-box** basis derived from `ORIGINAL_REQUEST.md` and `PROJECT.md`. Tests observe and assert against publicly exposed interfaces, user-facing UI elements, state machines, persistent storage effects (`GameStorage` / `SharedPreferences`), audio emission contracts (`AudioController`), and platform integration configurations (`AndroidManifest.xml`, `web/index.html`, `web/manifest.json`).

Tests NEVER rely on or assert against private implementation details. If an implementation detail changes while preserving functional behavior and contracts, tests MUST continue to pass.

### 1.2 Progressive Testability
During milestone execution (M1 through M5), tests adhere to **progressive testability**:
- Tests for completed milestones pass immediately and unconditionally.
- Tests for upcoming milestones are architecturally verified and execute their full logic as milestones complete and register their components via `MiniGameRegistry` and app contracts.
- No test suite file will block compilation or crash static analysis (`flutter analyze` and `flutter test`).

### 1.3 Determinism and State Isolation
- Every test is self-contained and sets up its own clean environment.
- In-memory mock storage (`SharedPreferences.setMockInitialValues({...})`) is instantiated per test to prevent cross-test leakage.
- Singletons such as `AudioController` are reset or initialized cleanly per test run.
- Tests do not rely on execution order or persistent file system state.

---

## 2. Feature Inventory Mapping

| # | Feature Area | Key Requirements | Test Suite File | Tiers Covered |
|---|--------------|------------------|-----------------|---------------|
| 1 | Branding & Splash & Hub | "WonderPlay Arcade" branding across Android/Web/App, bouncy animated splash screen, launcher icons, Hub presentation | `test/e2e/branding_and_hub_e2e_test.dart` | Tier 1, 2, 3, 4 |
| 2 | Merge Blacksmith (Game 1) | 4x5 forge grid (20 slots), 3s auto-spawner, drag-and-drop merge Lv 1..5, customer orders banner, AudioController & GameStorage | `test/e2e/merge_blacksmith_e2e_test.dart` | Tier 1, 2, 3, 4 |
| 3 | Gravity Glitch (Game 2) | FlameGame runner, RectangleHitbox collision, single-tap gravity flip, moving floor/ceiling spikes, 3 hearts life system, audio/storage | `test/e2e/gravity_glitch_e2e_test.dart` | Tier 1, 2, 3, 4 |
| 4 | Color Switch Courier (Game 3) | AnimationController loop, Red/Green/Blue cycling ship, downward laser gates with glyphs, player Y-crossing collision, audio/storage | `test/e2e/color_switch_courier_e2e_test.dart` | Tier 1, 2, 3, 4 |
| 5 | Registry & Storage Integration | MiniGameRegistry catalog, star persistence in GameStorage, category filtering, shared GameOver/Victory dialogs, global stars | `test/e2e/hub_integration_e2e_test.dart` | Tier 1, 2, 3, 4 |

---

## 3. 4-Tier Test Methodology

The E2E test suites implement a comprehensive 4-tier testing hierarchy guaranteeing at least 5 test cases per tier for each feature area:

### Tier 1: Feature Coverage (Happy Path & Core Capabilities)
- Verifies nominal functional behavior for all features specified in `ORIGINAL_REQUEST.md`.
- Focuses on primary user journeys: launching, displaying UI, user inputs, score progression, and state reporting.
- Derives expected outputs directly from authoritative requirement statements.

### Tier 2: Boundary & Corner Cases (Adversarial & Stress)
- Tests edge conditions, resource constraints, and boundary limits:
  - Empty vs full grid states (e.g. 20 slots full in Merge Blacksmith).
  - Maximum progression caps (e.g. attempting to merge Level 5 + Level 5).
  - Rapid multi-tap inputs (e.g. rapid gravity flipping or color cycling).
  - Post-collision invulnerability grace periods (1.5s immune window in Gravity Glitch).
  - Extreme screen dimensions, tablet aspect ratios, and orientations.
  - Storage corruption or missing preferences fallback.
  - Drag cancellations outside bounds.

### Tier 3: Cross-Feature Combinations (Pairwise & System Integration)
- Tests interactions between two or more subsystems:
  - Spawner timer firing concurrently with active user dragging.
  - AudioController mute toggles during in-game sound triggers.
  - Multi-game star accumulation and high score synchronization in `GameStorage`.
  - Game Over dialog actions (Retry vs Exit) updating Hub state and resetting game controller state.

### Tier 4: Real-World Application Scenarios
- End-to-end user workflows simulating realistic child play sessions:
  - Launch app -> Splash screen animation -> Hub card selection -> Complete gameplay session -> Star reward -> Hub return with updated total stars.
  - Switching between different mini-game categories while preserving global audio and progression states.

---

## 4. Test Execution Architecture & Commands

### 4.1 Running All Tests
To execute the full test suite including baseline and E2E tests:
```powershell
flutter test
```

### 4.2 Running Specific E2E Suites
```powershell
# Branding, Splash & Hub E2E
flutter test test/e2e/branding_and_hub_e2e_test.dart

# Merge Blacksmith E2E
flutter test test/e2e/merge_blacksmith_e2e_test.dart

# Gravity Glitch E2E
flutter test test/e2e/gravity_glitch_e2e_test.dart

# Color Switch Courier E2E
flutter test test/e2e/color_switch_courier_e2e_test.dart

# Hub & Registry Integration E2E
flutter test test/e2e/hub_integration_e2e_test.dart
```

### 4.3 Static Analysis
To verify code compliance, syntax, and zero lint warnings:
```powershell
flutter analyze
```

---

## 5. Authoritative Expected Output Derivation

| Test Area | Input | Authoritative Source | Expected Observable Output |
|-----------|-------|----------------------|---------------------------|
| App Title Branding | App manifest & main | `ORIGINAL_REQUEST.md` R1 | Title is "WonderPlay Arcade" in MaterialApp, AndroidManifest.xml, and web files |
| Splash Screen | Initial launch | `ORIGINAL_REQUEST.md` R1 | Displays animated "WonderPlay Arcade", transitions to `GameHubScreen` |
| Merge Blacksmith: Merge | Drag Lv 1 onto Lv 1 | `ORIGINAL_REQUEST.md` R2 | Target becomes Lv 2, score increases, `AudioController.playCorrect()` invoked |
| Merge Blacksmith: Max Lv | Drag Lv 5 onto Lv 5 | `PROJECT.md` & Explorer 3 | Merge rejected, items remain Lv 5, no invalid Lv 6 created |
| Gravity Glitch: Inversion | Screen tap | `ORIGINAL_REQUEST.md` R3 | Player vertical gravity vector inverts between floor and ceiling |
| Gravity Glitch: Obstacle | Collision with spike | `ORIGINAL_REQUEST.md` R3 | Life decremented from 3 to 2, 1.5s grace period activated |
| Color Switch Courier: Ship | Tap on screen | `ORIGINAL_REQUEST.md` R4 | Ship cycles Red -> Green -> Blue -> Red |
| Color Switch Courier: Gate | Matching gate Y | `ORIGINAL_REQUEST.md` R4 | +1 score, `AudioController.playCorrect()`, gate marked passed |
| Color Switch Courier: Gate | Mismatch gate Y | `ORIGINAL_REQUEST.md` R4 | Game Over triggered, `AudioController.playWrong()`, final score reported |
| Storage & Registry | Save level result | `PROJECT.md` § Interface Contracts | `storage.getLevelStars(gameId, level)` reflects stars on Hub card |

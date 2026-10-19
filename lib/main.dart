import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio/audio_controller.dart';
import 'core/storage/game_storage.dart';
import 'core/theme/app_theme.dart';
import 'hub/views/game_hub_screen.dart';
import 'splash/views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow both portrait and landscape for tablets and phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final storage = await GameStorage.init();
  final audioController = AudioController();
  await audioController.init(storage);

  runApp(KidsGamesApp(storage: storage));
}

class KidsGamesApp extends StatelessWidget {
  final GameStorage storage;
  final bool skipSplash;

  const KidsGamesApp({
    super.key,
    required this.storage,
    this.skipSplash = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WonderPlay Arcade',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: skipSplash
          ? GameHubScreen(storage: storage)
          : SplashScreen(storage: storage),
    );
  }
}

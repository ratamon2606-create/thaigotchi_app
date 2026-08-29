import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'services/settings_service.dart';
import 'services/rag_service.dart';
import 'services/voice_service.dart';
import 'services/locations_service.dart';
import 'services/chat_history_service.dart';
import 'screens/adopt_screen.dart';
import 'screens/searching_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.cafeCream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize services
  final settings = SettingsService();
  await settings.init();
  
  await LocalRAGService().init();
  await LocationsService().init();
  await ChatHistoryService().init();
  await VoiceService().init(language: settings.languageCode);
  
  runApp(const ThaigotchiApp());
}

class ThaigotchiApp extends StatelessWidget {
  const ThaigotchiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thaigotchi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    
    if (settings.hasAdoptedPet) {
      return const SearchingScreen();
    } else {
      return const AdoptScreen();
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/camera_screen.dart';
import 'screens/splash_screen.dart';
import 'services/admob_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdMobService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Tag Camera Nandu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFF2979FF),
          surface: Color(0xFF121216),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontFamily: 'Outfit'),
          bodyMedium: TextStyle(fontFamily: 'Outfit'),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

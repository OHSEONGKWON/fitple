import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qfppujcxpzncjufxbpvx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcHB1amN4cHpuY2p1ZnhicHZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzI4MjEsImV4cCI6MjA5MDIwODgyMX0.tEcMO4thoyCJzk4Qt_XkepWEQ3kHxEaQGSW-S6R8MVM',
  );

  runApp(const FitpleApp());
}

class FitpleApp extends StatelessWidget {
  const FitpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitple',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Pretendard',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Pretendard',
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

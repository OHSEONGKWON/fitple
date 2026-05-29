import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await FlutterNaverMap().init(clientId: '6nqz044aws');
  }

  await Supabase.initialize(
    url: 'https://qfppujcxpzncjufxbpvx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcHB1amN4cHpuY2p1ZnhicHZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzI4MjEsImV4cCI6MjA5MDIwODgyMX0.tEcMO4thoyCJzk4Qt_XkepWEQ3kHxEaQGSW-S6R8MVM',
  );

  if (!kIsWeb) {
    await NotificationService.initialize();
  }
  runApp(const FitpleApp());
}

class FitpleApp extends StatelessWidget {
  const FitpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitple',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _dotCount = 1;
  late Timer _animationTimer;

  @override
  void initState() {
    super.initState();

    _animationTimer = Timer.periodic(const Duration(milliseconds: 400), (
      timer,
    ) {
      setState(() {
        _dotCount = (_dotCount % 4) + 1;
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      _animationTimer.cancel();
      if (!mounted) return;

      // 로그인 상태 확인
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 로그인된 사용자 -> 홈 화면으로
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainHomeScreen()),
        );
      } else {
        // 미로그인 -> 로그인 화면으로
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String dots = '.' * _dotCount;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Fitple',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '메이트를 만나러 가는중$dots',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

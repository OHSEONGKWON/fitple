import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController signUpEmailController = TextEditingController();
  final TextEditingController signUpPasswordController =
      TextEditingController();
  final TextEditingController signUpNicknameController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundGlow(
            top: -50,
            left: -100,
            color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
          ),
          _buildBackgroundGlow(
            bottom: -50,
            right: -50,
            color: const Color(0xFF00E676).withValues(alpha: 0.2),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 95),
                            Text(
                              'Fitple',
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w900,
                                color: isDarkMode ? Colors.white : Colors.black,
                                height: 1.1,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              '우리 동네에서 함께 땀 흘릴\n메이트를 지금 바로 찾아보세요.',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showLoginModal(context, isDarkMode),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  '시작하기',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 35),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Positioned _buildBackgroundGlow({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  void _showLoginModal(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    'Fitple 로그인',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 35),
                  _buildTextField(
                    label: '아이디 (이메일)',
                    hint: 'example@gmail.com',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    label: '비밀번호',
                    hint: '비밀번호를 입력하세요',
                    controller: passwordController,
                    obscureText: true,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await Supabase.instance.client.auth
                              .signInWithPassword(
                                email: emailController.text,
                                password: passwordController.text,
                              );
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainHomeScreen(),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '로그인 실패: 가입되지 않은 아이디이거나 비밀번호가 틀렸습니다.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.of(context).size.height - 120,
                              ),
                              dismissDirection: DismissDirection.up,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildSignUpRow(context, isDarkMode),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      '또는',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.black38,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildGoogleButton(context, isDarkMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSignUpModal(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    'Fitple 회원가입',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 35),
                  _buildTextField(
                    label: '닉네임',
                    hint: '사용하실 닉네임을 입력하세요',
                    controller: signUpNicknameController,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    label: '이메일',
                    hint: 'example@gmail.com',
                    controller: signUpEmailController,
                    keyboardType: TextInputType.emailAddress,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    label: '비밀번호',
                    hint: '비밀번호를 입력하세요',
                    controller: signUpPasswordController,
                    obscureText: true,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await Supabase.instance.client.auth.signUp(
                            email: signUpEmailController.text,
                            password: signUpPasswordController.text,
                            data: {'display_name': signUpNicknameController.text},
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '회원가입이 완료되었습니다. 로그인을 진행해주세요.',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: const Color(0xFF00E676),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.of(context).size.height - 56,
                              ),
                              dismissDirection: DismissDirection.up,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          _showLoginModal(context, isDarkMode);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '회원가입 실패: 이메일 형식이 틀렸거나 이미 가입된 계정입니다.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                MediaQuery.of(context).size.height - 120,
                              ),
                              dismissDirection: DismissDirection.up,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '회원가입 완료',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '이미 계정이 있으신가요?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showLoginModal(context, isDarkMode);
                        },
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextField _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    required bool isDarkMode,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white30 : Colors.black26,
        ),
      ),
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      keyboardType: keyboardType,
    );
  }

  Row _buildSignUpRow(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '아직 계정이 없으신가요?',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showSignUpModal(context, isDarkMode);
          },
          child: const Text(
            '회원가입',
            style: TextStyle(
              color: Color(0xFF00E676),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  SizedBox _buildGoogleButton(BuildContext context, bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainHomeScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDarkMode ? Colors.white24 : Colors.black26,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          '구글로 시작하기',
          style: TextStyle(
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

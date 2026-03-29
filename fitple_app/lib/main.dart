// lib/main.dart

import 'package:flutter/material.dart'; // 기본 UI 패키지
import 'dart:async'; // 비동기 작업 패키지
import 'package:supabase_flutter/supabase_flutter.dart';

// 앱 실행 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://qfppujcxpzncjufxbpvx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmcHB1amN4cHpuY2p1ZnhicHZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzI4MjEsImV4cCI6MjA5MDIwODgyMX0.tEcMO4thoyCJzk4Qt_XkepWEQ3kHxEaQGSW-S6R8MVM',
  );
  
  runApp(const FitpleApp());
}

// 앱 최상위 위젯 실행 
class FitpleApp extends StatelessWidget {
  const FitpleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitple',
      
      // 1. 라이트 모드 테마, 배경색, 전체 글꼴 설정
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Pretendard',
      ),

      // 2. 다크 모드 테마, 배경색, 전체 글꼴 설정
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), 
        fontFamily: 'Pretendard',
      ),

      // OS 설정에 따라 테마 설정
      themeMode: ThemeMode.system, 
      
      // 시작 화면을 로딩 화면으로 변경
      home: const SplashScreen(), 
      debugShowCheckedModeBanner: false,
    );
  }
}

// 1. 로딩 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// 점 갯수 및 타이머 제어
class _SplashScreenState extends State<SplashScreen> {
  int _dotCount = 1;
  late Timer _animationTimer;

  // 처음 실행 시 초기화 함수 
  @override
  void initState() {
    super.initState();
    
    // 1번 타이머, 0.4s 마다 실행
    _animationTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _dotCount = (_dotCount % 4) + 1;
      });
    });

    // 2번 타이머, 3초 후 실행
    Future.delayed(const Duration(seconds: 3), () {
      _animationTimer.cancel();
      
      // 로딩 도중(3s) 앱 종료 시 타이머 미실행 함수
      if (!mounted) return; 

      // 뒤로가기 방지 및 시작 화면 로드 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  // 로딩 종료 후 타이머 킬
  @override
  void dispose() {
    _animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    // 현재 테마에 따른 true/false 값 생성
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String dots = '.' * _dotCount;

    // 화면 구성 및 배치
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            // 로딩 화면 앱 이름 텍스트
            Text(
              'Fitple',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : Colors.black, 
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20), // 앱이름, 텍스트사이 여백 생성
            
            // 로딩 화면 부제 텍스트 및 점 
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
 

// 2. 시작 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 로그인용 컨트롤러
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // 회원가입용 컨트롤러 3개 추가!
  final TextEditingController signUpEmailController = TextEditingController();
  final TextEditingController signUpPasswordController = TextEditingController();
  final TextEditingController signUpNicknameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 현재 테마에 따른 true/false 값 생성
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 화면 구성 및 배치
    return Scaffold(
      body: Stack(
        children: [
          // 배경 왼쪽 위 보라색 조명 효과
          _buildBackgroundGlow(
              top: -50, left: -100, color: Colors.deepPurpleAccent.withValues(alpha: 77)),
          // 배경 오른쪽 아래 네온그린 조명 효과
          _buildBackgroundGlow(
              bottom: -50, right: -50, color: const Color(0xFF00E676).withValues(alpha: 51)),
          // SafeArea: 스마트폰의 노치(M자 탈모), 상단 상태바 등에 글씨가 가려지지 않게 안전 구역 설정
          SafeArea(
            // 화면 크기가 변해도 내용이 깨지지 않게 해주는 반응형 구조 설정
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 95),
                            // 시작 화면 메인 텍스트
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
                            // 시작 화면 서브 텍스트
                            Text(
                              '우리 동네에서 함께 땀 흘릴\n메이트를 지금 바로 찾아보세요.',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white.withValues(alpha: 179) : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const Spacer(),
                            // 시작하기 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton(
                                onPressed: () {
                                  // 버튼 클릭 시 ID/PW 입력 모달창 로딩
                                  _showLoginModal(context, isDarkMode);
                                },
                                // 버튼 디자인
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

  // 2. 시작 화면 - 글로우 이펙트 기능
  Positioned _buildBackgroundGlow({double? top, double? left, double? bottom, double? right, required Color color}) {
    return Positioned(
      top: top, left: left, bottom: bottom, right: right,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  // 2-1. 로그인 화면 (서브 창)
  void _showLoginModal(BuildContext context, bool isDarkMode) {
    // 로그인 모달 창 생성
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (BuildContext context) {
        return SingleChildScrollView( 
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              // 로그인 모달창 디자인
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, 
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25), topRight: Radius.circular(25), 
                ),
              ),
              padding: const EdgeInsets.all(30.0), 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5, margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[300], 
                        borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                  ),
                  Text("Fitple 로그인", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                  const SizedBox(height: 35),
                  // 아이디 입력칸
                  _buildTextField(label: '아이디 (이메일)', hint: 'example@gmail.com', controller: emailController, keyboardType: TextInputType.emailAddress, isDarkMode: isDarkMode),
                  const SizedBox(height: 15),
                  // 비밀번호 입력칸
                  _buildTextField(label: '비밀번호', hint: '비밀번호를 입력하세요', controller: passwordController, obscureText: true, isDarkMode: isDarkMode),
                  const SizedBox(height: 35),
                  //로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          // 1. Supabase 서버에 아이디/비밀번호가 맞는지 검사 요청!
                          await Supabase.instance.client.auth.signInWithPassword(
                            email: emailController.text, // 사용자가 입력한 이메일
                            password: passwordController.text, // 사용자가 입력한 비밀번호
                          );
                          
                          // 2. 위 검사를 무사히 통과(성공)했을 때만 홈 화면으로 이동!
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => const MainHomeScreen()),
                          );
                        } catch (e) {
                          // 3. 에러 발생 시 창을 유지하고 화면 상단에 경고 메시지만 띄우기
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '로그인 실패: 가입되지 않은 아이디이거나 비밀번호가 틀렸습니다.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(
                                16, 
                                0, 
                                16, 
                                MediaQuery.of(context).size.height - 120, // 화면 상단으로 올리기
                              ),
                              dismissDirection: DismissDirection.up,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676), 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('로그인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // 회원가입 버튼
                  _buildSignUpRow(context, isDarkMode),
                  const SizedBox(height: 5),
                  // "또는" 구분 텍스트
                  Center(child: Text('또는', style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, fontSize: 15))),
                  const SizedBox(height: 15),
                  //구글 로그인 버튼 (임시로 디자인 요소만 추가 해놓음)
                  _buildGoogleButton(context, isDarkMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 2-2. 회원가입 화면 (서브 창)  
  void _showSignUpModal(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (BuildContext context) {
        return SingleChildScrollView( 
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, 
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25), topRight: Radius.circular(25), 
                ),
              ),
              padding: const EdgeInsets.all(30.0), 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5, margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[300], 
                        borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                  ),
                  Text("Fitple 회원가입", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                  const SizedBox(height: 35),
                  
                  // 회원정보 입력칸 3개 (닉네임, 이메일, 비번)에 컨트롤러 연결
                  _buildTextField(label: '닉네임', hint: '사용하실 닉네임을 입력하세요', controller: signUpNicknameController, isDarkMode: isDarkMode),
                  const SizedBox(height: 15),
                  _buildTextField(label: '이메일', hint: 'example@gmail.com', controller: signUpEmailController, keyboardType: TextInputType.emailAddress, isDarkMode: isDarkMode),
                  const SizedBox(height: 15),
                  _buildTextField(label: '비밀번호', hint: '비밀번호를 입력하세요', controller: signUpPasswordController, obscureText: true, isDarkMode: isDarkMode),
                  const SizedBox(height: 35),
                  
                  // 회원가입 완료 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          // 1. Supabase 서버에 회원가입 요청!
                          await Supabase.instance.client.auth.signUp(
                            email: signUpEmailController.text, // 입력한 이메일
                            password: signUpPasswordController.text, // 입력한 비밀번호
                            data: {'username': signUpNicknameController.text}, // 닉네임 데이터
                          );

                          if (!context.mounted) return;
                          // 2. 가입 성공 시 회원가입 창 닫기 및 알림
                          Navigator.pop(context); 
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '회원가입이 완료되었습니다. 로그인을 진행해주세요.',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: const Color(0xFF00E676), 
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB( 
                                16, 0, 16, MediaQuery.of(context).size.height - 56, 
                              ),
                              dismissDirection: DismissDirection.up, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          // 로그인 모달창 로딩
                          _showLoginModal(context, isDarkMode);
                        } catch (e) {
                          // 3. 가입 실패 시 에러 알림 띄우기 (창은 유지)
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '회원가입 실패: 이메일 형식이 틀렸거나 이미 가입된 계정입니다.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.height - 120),
                              dismissDirection: DismissDirection.up,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676), 
                        foregroundColor: Colors.black, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('회원가입 완료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // 로그인 모달창 이동 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('이미 계정이 있으신가요?', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14)),
                      TextButton(
                        onPressed: () {
                          // 회원가입 모달창 닫기
                          Navigator.pop(context); 
                          // 로그인 모달창 로딩
                          _showLoginModal(context, isDarkMode); 
                        }, 
                        child: const Text('로그인', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 14))
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

  // 텍스트 입력창 관련 함수 (텍스트 비공개, 입력창 이름 띄우기, 투명 글씨 힌트, 입력창 배경색 설정, 테마 연동, 글씨 색상, 입력 형식 지정)
  TextField _buildTextField({required String label, required String hint, TextEditingController? controller, bool obscureText = false, TextInputType? keyboardType, required bool isDarkMode}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label, hintText: hint, 
        filled: true, 
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100], 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54), 
        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black26),
      ),
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), 
      keyboardType: keyboardType,
    );
  }

  // 텍스트와 버튼을 가로 배치 함수
  Row _buildSignUpRow(BuildContext context, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('아직 계정이 없으신가요?', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14)),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // 회원가입 모달창 로딩
            _showSignUpModal(context, isDarkMode);
          }, 
          child: const Text('회원가입', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 14))
        ),
      ],
    );
  }

  // 구글 로그인 버튼
  SizedBox _buildGoogleButton(BuildContext context, bool isDarkMode) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: OutlinedButton(
        onPressed: () { 
          Navigator.pop(context);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainHomeScreen()));
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black26, width: 1.0), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
        ),
        child: Text('구글로 시작하기', style: TextStyle(fontSize: 18, color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// 3. 메인 홈 화면 (MainHomeScreen)
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 현재 테마에 따른 true/false 값 생성
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 하단 네비게이션바 (메뉴 4가지) 
    final List<Widget> pages = [
      Center(child: Text("임시 홈 화면", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 18))),
      Center(child: Text("임시 탐색 화면", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 18))),
      Center(child: Text("임시 커뮤니티 화면", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 18))),
      Center(child: Text("임시 프로필 화면", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 18))),
    ];

    return Scaffold(
      extendBody: true, 
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      // 상단 앱바
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white, 
        elevation: 0,
        titleSpacing: 20,
        // 상단 앱바 왼쪽 영역
        title: Row(
          children: [
            // 로고
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, color: Colors.black, size: 18),
            ),
            const SizedBox(width: 12),
            // 앱 이름 텍스트
            Text(
              'Fitple',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: -0.5),
            ),
          ],
        ),
        // 상단 앱바 오른쪽 영역
        actions: [
          IconButton(
            onPressed: () {},
            // 말풍선 아이콘
            icon: Icon(
              Icons.chat_bubble_outline, 
              color: isDarkMode ? Colors.white : Colors.black, 
              size: 28, 
            ),
          ),
          const SizedBox(width: 0), 

          IconButton(
            onPressed: () {},
            // 알림 아이콘
            icon: Icon(Icons.notifications_none_rounded, color: isDarkMode ? Colors.white : Colors.black, size: 28),
          ),
          const SizedBox(width: 10), 
        ],
      ),
      // 화면 중앙의 본문 영역
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: pages[_currentIndex],
          ),
        ),
      ),

      // 화면 플러스(+) 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      // 하단 네비게이션 바 디자인 및 표시하는 메뉴 및 내용 변경
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, 
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withValues(alpha: 77) : Colors.grey.withValues(alpha: 77),
                blurRadius: 10,
                offset: const Offset(0, 4), 
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent, 
              elevation: 0, 
              selectedItemColor: const Color(0xFF00E676),
              unselectedItemColor: isDarkMode ? Colors.white.withValues(alpha: 128) : Colors.black45,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 26,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
                BottomNavigationBarItem(icon: Icon(Icons.search), label: '탐색'),
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '커뮤니티'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '프로필'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
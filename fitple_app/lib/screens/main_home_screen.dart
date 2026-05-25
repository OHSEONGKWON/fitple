import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'gather_screen.dart';
import 'calendar_screen.dart';
import 'chat_list_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      HomeScreen(
        onNavigateToGather: () => changeTab(2),
        onNavigateToCalendar: () => changeTab(1),
        onNavigateToProfile: () => changeTab(3),
      ),
      const CalendarScreen(),
      const GatherScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: GestureDetector(
          onTap: () => setState(() => _currentIndex = 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Fitple',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatListScreen()),
              );
            },
            icon: Icon(
              Icons.chat_bubble_outline,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_none_rounded,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
        ],//actions
      ),
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF00E676),
              unselectedItemColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black45,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedFontSize: 14,
              unselectedFontSize: 13,
              iconSize: 28,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: '홈',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: '일정',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_outlined),
                  label: '모집',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: '프로필',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
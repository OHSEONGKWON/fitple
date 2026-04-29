import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_screen.dart';
import 'gather_edit_screen.dart';
import 'gather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentGatherings = [];
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final nickname = user.userMetadata?['display_name'] as String? ??
        user.email?.split('@').first ??
        '회원';

    try {
      final data = await Supabase.instance.client
          .from('gatherings')
          .select()
          .order('created_at', ascending: false)
          .limit(6);

      if (mounted) {
        setState(() {
          _nickname = nickname;
          _recentGatherings = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nickname = nickname);
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '러닝':
        return Colors.redAccent;
      case '축구':
        return Colors.green;
      case '족구':
        return Colors.orange;
      case '배구':
        return Colors.blue;
      case '배드민턴':
        return Colors.purple;
      case '헬스':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatTimeAgo(String createdAt) {
    final created = DateTime.parse(createdAt).toLocal();
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 인사 배너
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nickname.isEmpty
                              ? '안녕하세요! 👋'
                              : '안녕하세요, $_nickname님! 👋',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '오늘도 함께 땀 흘릴 메이트를\n찾아볼까요?',
                          style: TextStyle(
                              fontSize: 13, color: Colors.black87, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const Text('🏃', style: TextStyle(fontSize: 52)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 빠른 메뉴
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('빠른 메뉴',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _QuickTile(
                    icon: Icons.search_rounded,
                    label: '모집 탐색',
                    color: Colors.blueAccent,
                    isDarkMode: isDarkMode,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GatherScreen())),
                  ),
                  const SizedBox(width: 12),
                  _QuickTile(
                    icon: Icons.add_circle_outline_rounded,
                    label: '모집하기',
                    color: const Color(0xFF00E676),
                    isDarkMode: isDarkMode,
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GatherEditScreen(),
                            fullscreenDialog: true),
                      );
                      if (result == true) _loadData();
                    },
                  ),
                  const SizedBox(width: 12),
                  _QuickTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '채팅',
                    color: Colors.orange,
                    isDarkMode: isDarkMode,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const ChatListScreen())),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 최근 모집
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('최근 모집 ✨',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GatherScreen())),
                    child: const Text('전체보기',
                        style: TextStyle(
                            color: Color(0xFF00E676), fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_recentGatherings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('아직 모집글이 없어요.',
                      style: TextStyle(color: subTextColor, fontSize: 14)),
                ),
              )
            else
              SizedBox(
                height: 164,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _recentGatherings.length,
                  itemBuilder: (context, index) {
                    final g = _recentGatherings[index];
                    final accent = _categoryColor(g['category'] ?? '기타');
                    final current = (g['current_members'] ?? 0) as int;
                    final max = (g['max_members'] ?? 1) as int;
                    return Container(
                      width: 162,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border(left: BorderSide(color: accent, width: 4)),
                        boxShadow: [
                          if (!isDarkMode)
                            BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(g['category'] ?? '기타',
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              g['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  height: 1.35),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: max > 0 ? current / max : 0,
                              backgroundColor: isDarkMode
                                  ? Colors.white12
                                  : Colors.grey[200],
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accent),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('👥 $current/$max',
                                  style: TextStyle(
                                      color: subTextColor, fontSize: 11)),
                              Text(
                                  _formatTimeAgo(g['created_at'] ??
                                      DateTime.now().toIso8601String()),
                                  style: TextStyle(
                                      color: subTextColor, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDarkMode)
                BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

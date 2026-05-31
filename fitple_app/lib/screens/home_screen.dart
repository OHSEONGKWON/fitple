import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_screen.dart';
import 'gather_edit_screen.dart';
import 'gather_screen.dart';
import 'story_add_screen.dart';
import 'story_show_screen.dart';
import 'dart:typed_data';
import 'workout_cert_screen.dart';

class HomeScreen extends StatefulWidget { //다른 창으로 바로 넘어갈 수 있도록 함수를 선언
  final VoidCallback onNavigateToGather;
  final VoidCallback onNavigateToCalendar;
  final VoidCallback onNavigateToProfile;

  const HomeScreen({
    super.key,
    required this.onNavigateToGather,
    required this.onNavigateToCalendar,
    required this.onNavigateToProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentGatherings = [];
  List<Map<String, dynamic>> _storyItems = []; // {imageUrl, nickname, createdAt, isOwn, storyId, userId}
  String? _myStoryUrl; // 내 최신 스토리 공개 URL
  String _nickname = '';
  String _userId = '';
  bool _isCertifiedToday = false;
  int _streakCount = 0;

  static String get _todayStr {
    final now = DateTime.now().toLocal();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadWorkoutStatus();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final nickname = user.userMetadata?['display_name'] as String? ??
        user.email?.split('@').first ??
        '회원';

    try {
      // 팔로잉 유저 ID 목록
      final followingRaw = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);
      final followingIds = (followingRaw as List)
          .map((f) => f['following_id'] as String)
          .toList();

      final results = await Future.wait([
        Supabase.instance.client
            .from('gatherings')
            .select()
            .order('created_at', ascending: false)
            .limit(6),
        Supabase.instance.client
            .from('stories')
            .select()
            .gt('expires_at', DateTime.now().toIso8601String())
            .order('created_at', ascending: false),
      ]);

      final gatheringsData = results[0] as List;
      final allStoriesData = results[1] as List;

      // 내 스토리 + 팔로잉 유저 스토리만 표시
      final storiesData = allStoriesData.where((s) {
        final uid = s['user_id'] as String;
        return uid == user.id || followingIds.contains(uid);
      }).toList();

      // 유저별 최신 스토리 1개씩만 추출
      final Map<String, Map<String, dynamic>> latestPerUser = {};
      for (final s in storiesData) {
        final uid = s['user_id'] as String;
        if (!latestPerUser.containsKey(uid)) {
          latestPerUser[uid] = Map<String, dynamic>.from(s);
        }
      }

      // 공개 URL 변환
      final storyItems = <Map<String, dynamic>>[];
      String? myStoryUrl;

      for (final entry in latestPerUser.entries) {
        final s = entry.value;
        final url = Supabase.instance.client.storage
            .from('stories')
            .getPublicUrl(s['image_url'] as String);
        final isOwn = entry.key == user.id;
        if (isOwn) myStoryUrl = url;
        storyItems.add({
          'imageUrl': url,
          'nickname': s['user_nickname'] as String? ?? '사용자',
          'createdAt': s['created_at'] as String?,
          'isOwn': isOwn,
          'userId': entry.key,
          'storyId': s['id'] as String?,
        });
      }

      if (mounted) {
        setState(() {
          _nickname = nickname;
          _userId = user.id;
          _recentGatherings = List<Map<String, dynamic>>.from(gatheringsData);
          _storyItems = storyItems;
          _myStoryUrl = myStoryUrl;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nickname = nickname);
    }
  }

  Future<void> _loadWorkoutStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('workout_certifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('cert_date', _todayStr)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_points')
            .select('streak_count')
            .eq('user_id', user.id)
            .maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
          _isCertifiedToday = results[0] != null;
          _streakCount = results[1]?['streak_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  IconData _categoryIconData(String category) {
    switch (category) {
      case '축구': return Icons.sports_soccer;
      case '족구': return Icons.sports_volleyball;
      case '배구': return Icons.sports_volleyball;
      case '배드민턴': return Icons.sports_tennis;
      case '헬스': return Icons.fitness_center;
      case '러닝': return Icons.directions_run;
      default: return Icons.sports;
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

  Future<void> _uploadStory(Uint8List fileBytes) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 스토리 파일이름: stories/{userId}/{timestamp}.jpg
      final fileName = 'stories/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 파일 업로드
      await Supabase.instance.client.storage
          .from('stories')
          .uploadBinary(fileName, fileBytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      // 데이터베이스에 스토리 기록 저장
      await Supabase.instance.client.from('stories').insert({
        'user_id': user.id,
        'image_url': fileName,
        'user_nickname': user.userMetadata?['display_name'] ?? user.email?.split('@').first ?? '사용자',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });

      if (mounted) {
        await _loadData(); // 스토리 목록 새로고침
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('스토리가 업로드되었습니다! 🎉'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            // 스토리 섹션
            Container(
              height: 115,
              margin: const EdgeInsets.only(top: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 1. 내 스토리 (항상 첫번째)
                  GestureDetector(
                    onTap: () {
                      if (_myStoryUrl != null) {
                        // 내 스토리 보기
                        final myStories = _storyItems
                            .where((s) => s['isOwn'] == true)
                            .toList();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoryViewScreen(
                              stories: myStories,
                              currentUserId: _userId,
                              currentUserNickname: _nickname,
                              onStoryDeleted: _loadData,
                            ),
                          ),
                        );
                      } else {
                        // 스토리 추가
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StorySelectionScreen(
                              onImageSelected: (bytes) => _uploadStory(bytes),
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  border: _myStoryUrl != null
                                      ? Border.all(color: const Color(0xFF00E676), width: 3)
                                      : null,
                                ),
                                child: ClipOval(
                                  child: _myStoryUrl != null
                                      ? Image.network(_myStoryUrl!, fit: BoxFit.cover,
                                          errorBuilder: (context, error, _) =>
                                              const Center(child: Text('👤', style: TextStyle(fontSize: 34))))
                                      : const Center(child: Text('👤', style: TextStyle(fontSize: 34))),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StorySelectionScreen(
                                        onImageSelected: (bytes) => _uploadStory(bytes),
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '내 스토리',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. 다른 유저 스토리
                  ..._storyItems
                      .where((s) => s['isOwn'] != true)
                      .map<Widget>((story) => GestureDetector(
                            onTap: () {
                              final userStories = _storyItems
                                  .where((s) => s['userId'] == story['userId'])
                                  .toList();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoryViewScreen(
                                    stories: userStories,
                                    currentUserId: _userId,
                                    currentUserNickname: _nickname,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF00E676), width: 3),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        story['imageUrl'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, _) =>
                                            const Center(child: Text('👤', style: TextStyle(fontSize: 34))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 76,
                                    child: Text(
                                      story['nickname'] as String? ?? '사용자',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
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
                      fontSize: 19,
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
                    onTap: widget.onNavigateToGather,
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

            const SizedBox(height: 18),

            // 오운완 인증 배너
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _WorkoutBanner(
                isCertified: _isCertifiedToday,
                streak: _streakCount,
                isDarkMode: isDarkMode,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WorkoutCertScreen()),
                  );
                  _loadWorkoutStatus();
                },
              ),
            ),

            const SizedBox(height: 35),

            // 최근 모집
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('최근 모집 ✨',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => widget.onNavigateToGather,
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
              Container(
                color: cardColor,
                child: Column(
                  children: [
                    Divider(height: 1, color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                    ..._recentGatherings.take(4).map((g) {
                      final accent = _categoryColor(g['category'] ?? '기타');
                      final current = (g['current_members'] ?? 0) as int;
                      final max = (g['max_members'] ?? 1) as int;
                      final isClosed = (g['is_closed'] ?? false) as bool;
                      final categoryIcon = _categoryIconData(g['category'] ?? '');
                      return Column(
                        children: [
                          InkWell(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const GatherScreen())),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 썸네일
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? (isDarkMode ? Colors.white12 : Colors.grey.shade200)
                                          : accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(categoryIcon, size: 28,
                                        color: isClosed ? Colors.grey : accent),
                                  ),
                                  const SizedBox(width: 12),
                                  // 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g['title'] ?? '',
                                            style: TextStyle(
                                                color: isClosed ? Colors.grey : textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(g['category'] ?? '',
                                                style: TextStyle(
                                                    color: isClosed ? Colors.grey : accent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600)),
                                            Text(' · ', style: TextStyle(color: subTextColor, fontSize: 12)),
                                            Text(_formatTimeAgo(g['created_at'] ?? DateTime.now().toIso8601String()),
                                                style: TextStyle(color: subTextColor, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(Icons.people_outline, size: 12, color: subTextColor),
                                            const SizedBox(width: 3),
                                            Text('$current/$max명',
                                                style: TextStyle(
                                                    color: isClosed ? Colors.grey : accent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: max > 0 ? (current / max).clamp(0.0, 1.0) : 0,
                                                  backgroundColor: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                                                  valueColor: AlwaysStoppedAnimation<Color>(isClosed ? Colors.grey : accent),
                                                  minHeight: 4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isClosed)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('마감',
                                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
                        ],
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _WorkoutBanner extends StatelessWidget {
  final bool isCertified;
  final int streak;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _WorkoutBanner({
    required this.isCertified,
    required this.streak,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isCertified) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘 오운완 완료!',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    Text('연속 $streak일째 운동 중 🔥',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            const Text('💪', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오운완 인증하기',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black)),
                  Text('인증하면 +10P 적립!',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Color(0xFF00E676)),
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

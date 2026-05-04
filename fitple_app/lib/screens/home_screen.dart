import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_list_screen.dart';
import 'gather_edit_screen.dart';
import 'gather_screen.dart';
import 'story_add_screen.dart';
import 'story_show_screen.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentGatherings = [];
  List<Map<String, dynamic>> _storyItems = []; // {imageUrl, nickname, createdAt, isOwn, storyId, userId}
  String? _myStoryUrl; // 내 최신 스토리 공개 URL
  String _nickname = '';
  String _userId = '';

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
      final storiesData = results[1] as List;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토리가 업로드되었습니다! 🎉'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      }
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
                                          errorBuilder: (_, __, ___) =>
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
                              fontSize: 12,
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
                      .map((story) => GestureDetector(
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
                                        errorBuilder: (_, __, ___) =>
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
                          ))
                      .toList(),
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

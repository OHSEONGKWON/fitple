import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  // 각 story 맵: {imageUrl, nickname, createdAt, isOwn, storyId, userId}
  final int initialIndex;
  final String currentUserId;
  final String currentUserNickname;
  final VoidCallback? onStoryDeleted;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.currentUserId,
    required this.currentUserNickname,
    this.initialIndex = 0,
    this.onStoryDeleted,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  final Set<String> _viewedStoryIds = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _nextStory();
      });
    _progressController.forward();
    _recordView();
  }

  // 조회 기록 저장 (타인 스토리만)
  void _recordView() {
    final story = widget.stories[_currentIndex];
    final storyId = story['storyId'] as String?;
    final isOwn = story['isOwn'] == true;
    if (storyId == null || isOwn || _viewedStoryIds.contains(storyId)) return;
    _viewedStoryIds.add(storyId);
    Supabase.instance.client.from('story_views').upsert({
      'story_id': storyId,
      'viewer_id': widget.currentUserId,
      'viewer_nickname': widget.currentUserNickname,
    }, onConflict: 'story_id,viewer_id').catchError((_) {});
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _progressController.forward();
      _recordView();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _progressController.forward();
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final created = DateTime.tryParse(createdAt)?.toLocal();
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _deleteStory() async {
    final story = widget.stories[_currentIndex];
    final storyId = story['storyId'] as String?;
    if (storyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('스토리 삭제'),
        content: const Text('이 스토리를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Storage에서 이미지 삭제
      final imageUrl = story['imageUrl'] as String? ?? '';
      final uri = Uri.tryParse(imageUrl);
      if (uri != null) {
        final segments = uri.pathSegments;
        final idx = segments.lastIndexOf('stories');
        if (idx >= 0 && idx + 1 < segments.length) {
          final storagePath = segments.sublist(idx + 1).join('/');
          await Supabase.instance.client.storage
              .from('stories')
              .remove([storagePath]);
        }
      }
      // DB에서 스토리 삭제
      await Supabase.instance.client
          .from('stories')
          .delete()
          .eq('id', storyId);

      if (mounted) {
        widget.onStoryDeleted?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showViewers() async {
    _progressController.stop();
    final story = widget.stories[_currentIndex];
    final storyId = story['storyId'] as String?;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ViewersSheet(storyId: storyId),
    );

    if (mounted) _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final topPadding = MediaQuery.of(context).padding.top;
    final isOwn = story['isOwn'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // 배경 이미지
            Positioned.fill(
              child: Image.network(
                story['imageUrl'] as String,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // 상단 그라데이션
            Positioned(
              top: 0, left: 0, right: 0,
              height: topPadding + 90,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),

            // 하단 그라데이션 (조회자 버튼 배경)
            if (isOwn)
              Positioned(
                bottom: 0, left: 0, right: 0, height: 100,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
              ),

            // 진행 바
            Positioned(
              top: topPadding + 8,
              left: 12, right: 12,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 2.5,
                      child: i < _currentIndex
                          ? Container(color: Colors.white)
                          : i == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressController,
                                  builder: (_, __) => LinearProgressIndicator(
                                    value: _progressController.value,
                                    backgroundColor: Colors.white30,
                                    valueColor:
                                        const AlwaysStoppedAnimation(Colors.white),
                                    minHeight: 2.5,
                                  ),
                                )
                              : Container(color: Colors.white30),
                    ),
                  );
                }),
              ),
            ),

            // 유저 정보
            Positioned(
              top: topPadding + 22,
              left: 16, right: 56,
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E676), width: 2),
                      color: Colors.grey[800],
                    ),
                    child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story['nickname'] as String? ?? '사용자',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _timeAgo(story['createdAt'] as String?),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 닫기 + 더보기(내 스토리 삭제) 버튼
            Positioned(
              top: topPadding + 24, right: 16,
              child: Row(
                children: [
                  if (isOwn)
                    GestureDetector(
                      onTap: () {
                        _progressController.stop();
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text('스토리 삭제',
                                      style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _deleteStory();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.cancel),
                                  title: const Text('취소'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _progressController.forward();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ).then((_) {
                          if (mounted) _progressController.forward();
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.more_vert, color: Colors.white, size: 28),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),

            // 하단 조회자 보기 버튼 (내 스토리일 때만)
            if (isOwn)
              Positioned(
                bottom: 28, left: 0, right: 0,
                child: GestureDetector(
                  onTap: _showViewers,
                  child: Column(
                    children: [
                      const Icon(Icons.keyboard_arrow_up,
                          color: Colors.white70, size: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.remove_red_eye_outlined,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('조회자 보기',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 조회자 목록 바텀시트 ────────────────────────────────────────────────────
class _ViewersSheet extends StatefulWidget {
  final String? storyId;
  const _ViewersSheet({required this.storyId});

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<Map<String, dynamic>> _viewers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadViewers();
  }

  Future<void> _loadViewers() async {
    if (widget.storyId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('story_views')
          .select()
          .eq('story_id', widget.storyId!)
          .order('viewed_at', ascending: false);
      setState(() {
        _viewers = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _timeAgo(String? t) {
    if (t == null) return '';
    final dt = DateTime.tryParse(t)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye, size: 20),
                const SizedBox(width: 8),
                Text(
                  _loading
                      ? '조회한 사람'
                      : '조회한 사람 ${_viewers.length}명',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          else if (_viewers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('아직 조회자가 없습니다',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _viewers.length,
                itemBuilder: (_, i) {
                  final v = _viewers[i];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isDarkMode ? Colors.grey[700] : Colors.grey[200],
                      ),
                      child: const Center(
                        child: Text('👤', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    title: Text(v['viewer_nickname'] as String? ?? '사용자'),
                    trailing: Text(
                      _timeAgo(v['viewed_at'] as String?),
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

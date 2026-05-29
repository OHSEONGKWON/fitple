import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_create_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  // postId → likeCount
  Map<String, int> _likeCounts = {};
  // postId → commentCount
  Map<String, int> _commentCounts = {};
  // postId → isLiked
  Map<String, bool> _likedPosts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // 내 게시글 + 팔로잉 유저 게시글
      final followingRaw = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me.id);
      final followingIds = (followingRaw as List)
          .map((f) => f['following_id'] as String)
          .toList()
        ..add(me.id);

      final postsData = await Supabase.instance.client
          .from('posts')
          .select()
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false);

      final posts = List<Map<String, dynamic>>.from(postsData as List);
      final postIds = posts.map((p) => p['id'] as String).toList();

      if (postIds.isEmpty) {
        if (mounted) {
          setState(() {
            _posts = posts;
            _isLoading = false;
          });
        }
        return;
      }

      // 좋아요 수
      final likesData = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .inFilter('post_id', postIds);
      final Map<String, int> likeCounts = {};
      for (final l in (likesData as List)) {
        final pid = l['post_id'] as String;
        likeCounts[pid] = (likeCounts[pid] ?? 0) + 1;
      }

      // 내가 좋아요한 글
      final myLikesData = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', me.id)
          .inFilter('post_id', postIds);
      final likedIds = (myLikesData as List)
          .map((l) => l['post_id'] as String)
          .toSet();

      // 댓글 수
      final commentsData = await Supabase.instance.client
          .from('post_comments')
          .select('post_id')
          .inFilter('post_id', postIds);
      final Map<String, int> commentCounts = {};
      for (final c in (commentsData as List)) {
        final pid = c['post_id'] as String;
        commentCounts[pid] = (commentCounts[pid] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _likeCounts = likeCounts;
          _commentCounts = commentCounts;
          _likedPosts = {for (final id in postIds) id: likedIds.contains(id)};
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    final wasLiked = _likedPosts[postId] ?? false;
    setState(() {
      _likedPosts[postId] = !wasLiked;
      _likeCounts[postId] =
          (_likeCounts[postId] ?? 0) + (wasLiked ? -1 : 1);
    });
    try {
      if (wasLiked) {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('user_id', me.id)
            .eq('post_id', postId);
      } else {
        await Supabase.instance.client.from('post_likes').insert({
          'user_id': me.id,
          'post_id': postId,
        });
      }
    } catch (_) {
      setState(() {
        _likedPosts[postId] = wasLiked;
        _likeCounts[postId] =
            (_likeCounts[postId] ?? 0) + (wasLiked ? 1 : -1);
      });
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final dt = DateTime.parse(iso);
    return '${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final bgColor =
        isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9F9);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final divColor = isDarkMode ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        color: const Color(0xFF00E676),
        onRefresh: _loadPosts,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)))
            : _posts.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_outlined,
                                  size: 64, color: subColor),
                              const SizedBox(height: 16),
                              Text('팔로잉한 유저의 게시글이 여기에 표시됩니다',
                                  style:
                                      TextStyle(color: subColor, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text('우측 하단 버튼으로 첫 게시글을 올려보세요',
                                  style:
                                      TextStyle(color: subColor, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _posts.length,
                    separatorBuilder: (context, _) =>
                        Divider(height: 8, color: divColor),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final postId = post['id'] as String;
                      final isLiked = _likedPosts[postId] ?? false;
                      final likeCount = _likeCounts[postId] ?? 0;
                      final commentCount = _commentCounts[postId] ?? 0;
                      final imageUrl = post['image_url'] != null
                          ? Supabase.instance.client.storage
                              .from('posts')
                              .getPublicUrl(post['image_url'] as String)
                          : null;

                      return Container(
                        color: cardColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 헤더
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserProfileScreen(
                                          userId:
                                              post['user_id'] as String,
                                          nickname: post['user_nickname']
                                                  as String? ??
                                              '사용자',
                                        ),
                                      ),
                                    ),
                                    child: Row(children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: const Color(0xFF00E676)
                                            .withValues(alpha: 0.2),
                                        child: const Icon(Icons.person,
                                            color: Color(0xFF00E676), size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['user_nickname'] as String? ??
                                                '사용자',
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            _timeAgo(
                                                post['created_at'] as String?),
                                            style: TextStyle(
                                                color: subColor, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ]),
                                  ),
                                  const Spacer(),
                                  // 본인 글이면 삭제 버튼
                                  if (post['user_id'] ==
                                      Supabase.instance.client.auth
                                          .currentUser?.id)
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz,
                                          color: subColor),
                                      color: cardColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      onSelected: (v) async {
                                        if (v == 'delete') {
                                          await Supabase.instance.client
                                              .from('posts')
                                              .delete()
                                              .eq('id', postId);
                                          _loadPosts();
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: const [
                                            Icon(Icons.delete_outline,
                                                size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('삭제',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ]),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),

                            // 이미지
                            if (imageUrl != null)
                              GestureDetector(
                                onDoubleTap: () => _toggleLike(postId),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, _) => Container(
                                    height: 200,
                                    color: isDarkMode
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey.shade200,
                                    child: Icon(Icons.image_outlined,
                                        color: subColor, size: 48),
                                  ),
                                ),
                              ),

                            // 액션 버튼
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 4),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleLike(postId),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        key: ValueKey(isLiked),
                                        color: isLiked
                                            ? Colors.redAccent
                                            : subColor,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$likeCount',
                                      style: TextStyle(
                                          color: subColor, fontSize: 13)),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(
                                          post: post,
                                          isLiked: isLiked,
                                          likeCount: likeCount,
                                        ),
                                      ),
                                    ).then((_) => _loadPosts()),
                                    child: Row(children: [
                                      Icon(Icons.chat_bubble_outline,
                                          color: subColor, size: 24),
                                      const SizedBox(width: 4),
                                      Text('$commentCount',
                                          style: TextStyle(
                                              color: subColor, fontSize: 13)),
                                    ]),
                                  ),
                                ],
                              ),
                            ),

                            // 캡션
                            if (post['content'] != null &&
                                (post['content'] as String).isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 2, 12, 10),
                                child: RichText(
                                  text: TextSpan(children: [
                                    TextSpan(
                                      text:
                                          '${post['user_nickname'] ?? '사용자'}  ',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    TextSpan(
                                      text: post['content'] as String,
                                      style: TextStyle(
                                          color: textColor, fontSize: 13),
                                    ),
                                  ]),
                                ),
                              )
                            else
                              const SizedBox(height: 8),

                            // 댓글 n개 보기
                            if (commentCount > 0)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailScreen(
                                      post: post,
                                      isLiked: isLiked,
                                      likeCount: likeCount,
                                    ),
                                  ),
                                ).then((_) => _loadPosts()),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 10),
                                  child: Text('댓글 $commentCount개 모두 보기',
                                      style: TextStyle(
                                          color: subColor, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostCreateScreen()),
        ).then((ok) { if (ok == true) _loadPosts(); }),
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}

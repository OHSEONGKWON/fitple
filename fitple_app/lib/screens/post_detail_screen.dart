import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isLiked;
  final int likeCount;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.isLiked,
    required this.likeCount,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _isLiked;
  late int _likeCount;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final data = await Supabase.instance.client
          .from('post_comments')
          .select()
          .eq('post_id', widget.post['id'] as String)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data as List);
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      if (_isLiked) {
        await Supabase.instance.client.from('post_likes').insert({
          'user_id': me.id,
          'post_id': widget.post['id'],
        });
      } else {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('user_id', me.id)
            .eq('post_id', widget.post['id'] as String);
      }
    } catch (_) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;
    setState(() => _isSendingComment = true);
    try {
      final nickname =
          me.userMetadata?['display_name'] as String? ??
              me.email?.split('@').first ?? '사용자';
      final inserted = await Supabase.instance.client
          .from('post_comments')
          .insert({
            'post_id': widget.post['id'],
            'user_id': me.id,
            'user_nickname': nickname,
            'content': content,
          })
          .select()
          .single();
      _commentController.clear();
      setState(() => _comments.add(Map<String, dynamic>.from(inserted)));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final divColor = isDarkMode ? Colors.white12 : Colors.grey.shade200;
    final post = widget.post;
    final imageUrl = post['image_url'] != null
        ? Supabase.instance.client.storage
            .from('posts')
            .getPublicUrl(post['image_url'] as String)
        : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('게시글',
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                // 게시글 본문
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: post['user_id'] as String,
                              nickname: post['user_nickname'] as String? ?? '사용자',
                            ),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              const Color(0xFF00E676).withValues(alpha: 0.2),
                          child: const Icon(Icons.person,
                              color: Color(0xFF00E676), size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['user_nickname'] as String? ?? '사용자',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text(_timeAgo(post['created_at'] as String?),
                              style: TextStyle(color: subColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 10),
                  Image.network(imageUrl, fit: BoxFit.cover,
                      width: double.infinity),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.redAccent : subColor,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          Text('$_likeCount',
                              style: TextStyle(color: subColor, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline, color: subColor, size: 22),
                      const SizedBox(width: 4),
                      Text('${_comments.length}',
                          style: TextStyle(color: subColor, fontSize: 13)),
                    ],
                  ),
                ),
                if (post['content'] != null &&
                    (post['content'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${post['user_nickname'] ?? '사용자'}  ',
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        TextSpan(
                          text: post['content'] as String,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                      ]),
                    ),
                  ),
                Divider(height: 1, color: divColor),

                // 댓글 목록
                if (_isLoadingComments)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00E676))),
                  )
                else
                  ..._comments.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF00E676)
                                  .withValues(alpha: 0.15),
                              child: const Icon(Icons.person,
                                  color: Color(0xFF00E676), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(children: [
                                      TextSpan(
                                        text:
                                            '${c['user_nickname'] ?? '사용자'}  ',
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      TextSpan(
                                        text: c['content'] as String? ?? '',
                                        style: TextStyle(
                                            color: textColor, fontSize: 13),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      _timeAgo(c['created_at'] as String?),
                                      style: TextStyle(
                                          color: subColor, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),

          // 댓글 입력
          Divider(height: 1, color: divColor),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF00E676).withValues(alpha: 0.2),
                    child: const Icon(Icons.person,
                        color: Color(0xFF00E676), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '댓글 달기...',
                        hintStyle: TextStyle(color: subColor),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSendingComment ? null : _sendComment,
                    child: _isSendingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00E676)))
                        : const Text('게시',
                            style: TextStyle(
                                color: Color(0xFF00E676),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

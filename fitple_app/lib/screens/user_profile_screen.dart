import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'follow_list_screen.dart';
import 'post_detail_screen.dart';
import 'review_history_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String nickname;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.nickname,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isFollowing = false;
  bool _hasPendingRequest = false;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  bool _isToggling = false;
  bool _isPrivate = false;
  double _temperature = 36.5;
  int _temperatureReviewCount = 0;
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    try {
      final data = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data as List);
          _loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _loadData() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    bool isFollowing = _isFollowing;
    bool hasPendingRequest = _hasPendingRequest;
    int followerCount = _followerCount;
    int followingCount = _followingCount;
    bool isPrivate = _isPrivate;
    double temperature = _temperature;
    int temperatureReviewCount = _temperatureReviewCount;

    // 팔로우 핵심 정보는 먼저 가져오고, 일부 부가 정보 실패가 전체를 망치지 않게 분리합니다.
    try {
      final followCheck = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', me.id)
          .eq('following_id', widget.userId)
          .maybeSingle();
      isFollowing = followCheck != null;
    } catch (_) {}

    try {
      final requestCheck = await Supabase.instance.client
          .from('follow_requests')
          .select('id')
          .eq('requester_id', me.id)
          .eq('target_id', widget.userId)
          .maybeSingle();
      hasPendingRequest = requestCheck != null;
    } catch (_) {
      hasPendingRequest = false;
    }

    try {
      final followerList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('following_id', widget.userId);
      followerCount = (followerList as List).length;
    } catch (_) {}

    try {
      final followingList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', widget.userId);
      followingCount = (followingList as List).length;
    } catch (_) {}

    try {
      final settings = await Supabase.instance.client
          .from('user_settings')
          .select('is_private')
          .eq('user_id', widget.userId)
          .maybeSingle();
      isPrivate = settings?['is_private'] as bool? ?? false;
    } catch (_) {}

    try {
      final tempRow = await Supabase.instance.client
          .from('user_temperature')
          .select('temperature, review_count')
          .eq('user_id', widget.userId)
          .maybeSingle();
      temperature = (tempRow?['temperature'] as num?)?.toDouble() ?? 36.5;
      temperatureReviewCount = (tempRow?['review_count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isFollowing = isFollowing;
      _hasPendingRequest = hasPendingRequest;
      _followerCount = followerCount;
      _followingCount = followingCount;
      _isPrivate = isPrivate;
      _temperature = temperature;
      _temperatureReviewCount = temperatureReviewCount;
      _isLoading = false;
    });
  }

  Future<void> _refreshFollowMeta() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    try {
      final followCheck = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', me.id)
          .eq('following_id', widget.userId)
          .maybeSingle();

      final followerList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('following_id', widget.userId);

      final followingList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', widget.userId);

      if (!mounted) return;
      setState(() {
        _isFollowing = followCheck != null;
        _followerCount = (followerList as List).length;
        _followingCount = (followingList as List).length;
      });
    } catch (_) {
      // 재조회 실패 시 기존 화면값을 유지합니다.
    }
  }

  Future<void> _handleFollowButton() async {
    if (_isToggling) return;
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    setState(() => _isToggling = true);
    try {
      if (_isFollowing) {
        // 언팔로우
        await Supabase.instance.client
            .from('follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', widget.userId);
        await _refreshFollowMeta();
      } else if (_hasPendingRequest) {
        // 요청 취소
        await Supabase.instance.client
            .from('follow_requests')
            .delete()
            .eq('requester_id', me.id)
            .eq('target_id', widget.userId);
        if (mounted) setState(() => _hasPendingRequest = false);
      } else if (_isPrivate) {
        // 비공개 계정 → 팔로우 요청 전송
        final myNickname =
            me.userMetadata?['display_name'] as String? ?? '사용자';
        try {
          await Supabase.instance.client.from('follow_requests').insert({
            'requester_id': me.id,
            'requester_nickname': myNickname,
            'target_id': widget.userId,
          });
        } catch (_) {
          // follow_requests 테이블 없으면 기본 컬럼만으로 재시도
          await Supabase.instance.client.from('follow_requests').insert({
            'requester_id': me.id,
            'target_id': widget.userId,
          });
        }
        if (mounted) setState(() => _hasPendingRequest = true);
      } else {
        // 공개 계정 → 바로 팔로우
        final myNickname =
            me.userMetadata?['display_name'] as String? ?? '사용자';
        var inserted = false;
        var duplicated = false;
        try {
          await Supabase.instance.client.from('follows').insert({
            'follower_id': me.id,
            'follower_nickname': myNickname,
            'following_id': widget.userId,
            'following_nickname': widget.nickname,
          });
          inserted = true;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            duplicated = true;
          } else {
            // 닉네임 컬럼이 없으면 기본 컬럼만으로 재시도
            try {
              await Supabase.instance.client.from('follows').insert({
                'follower_id': me.id,
                'following_id': widget.userId,
              });
              inserted = true;
            } on PostgrestException catch (fallbackError) {
              if (fallbackError.code == '23505') {
                duplicated = true;
              } else {
                rethrow;
              }
            }
          }
        }
        if (inserted || duplicated) {
          await _refreshFollowMeta();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  String get _buttonLabel {
    if (_isFollowing) return '팔로잉 ✓';
    if (_hasPendingRequest) return '요청됨';
    return '팔로우';
  }

  Color _buttonColor(bool isDarkMode) {
    if (_isFollowing || _hasPendingRequest) {
      return isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200;
    }
    return const Color(0xFF00E676);
  }

  Color _buttonTextColor(bool isDarkMode) {
    if (_isFollowing || _hasPendingRequest) {
      return isDarkMode ? Colors.white54 : Colors.black54;
    }
    return Colors.black;
  }

  Color _temperatureColor() {
    if (_temperature >= 40) return const Color(0xFFFF5722);
    if (_temperature >= 37) return const Color(0xFFFF9800);
    if (_temperature >= 35) return const Color(0xFF00E676);
    return const Color(0xFF42A5F5);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final me = Supabase.instance.client.auth.currentUser;
    final isOwnProfile = me?.id == widget.userId;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    final showPrivateLock = _isPrivate && !_isFollowing && !isOwnProfile;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.nickname,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      boxShadow: [
                        if (!isDarkMode)
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 아바타
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.black, size: 48),
                        ),
                        const SizedBox(height: 14),
                        Text(widget.nickname,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewHistoryScreen(
                                  userId: widget.userId,
                                  nickname: widget.nickname,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _temperatureColor().withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _temperatureColor().withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 16,
                                    color: _temperatureColor(),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_temperature.toStringAsFixed(1)}°C',
                                    style: TextStyle(
                                      color: _temperatureColor(),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '후기 $_temperatureReviewCount개',
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewHistoryScreen(
                                userId: widget.userId,
                                nickname: widget.nickname,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.rate_review_outlined,
                            size: 16,
                            color: Color(0xFF00E676),
                          ),
                          label: const Text(
                            '리뷰 보기',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00E676)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (_isPrivate) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 13, color: subColor),
                              const SizedBox(width: 4),
                              Text('비공개 계정',
                                  style: TextStyle(
                                      color: subColor, fontSize: 12)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // 팔로워 / 팔로잉 수 (탭 가능)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                      userId: widget.userId,
                                      isFollowers: true),
                                ),
                              ),
                              child: _CountItem(
                                  label: '팔로워',
                                  count: _followerCount,
                                  textColor: textColor,
                                  subTextColor: subColor),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: isDarkMode
                                  ? Colors.white12
                                  : Colors.black12,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 28),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                      userId: widget.userId,
                                      isFollowers: false),
                                ),
                              ),
                              child: _CountItem(
                                  label: '팔로잉',
                                  count: _followingCount,
                                  textColor: textColor,
                                  subTextColor: subColor),
                            ),
                          ],
                        ),

                        // 팔로우 버튼 (본인 프로필 제외)
                        if (!isOwnProfile) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 160,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isToggling
                                  ? null
                                  : _handleFollowButton,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _buttonColor(isDarkMode),
                                foregroundColor:
                                    _buttonTextColor(isDarkMode),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isToggling
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF00E676)))
                                  : Text(_buttonLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                            ),
                          ),
                          if (_hasPendingRequest)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('요청을 취소하려면 버튼을 탭하세요',
                                  style: TextStyle(
                                      color: subColor, fontSize: 11)),
                            ),
                        ],

                        // 비공개 계정 잠금 안내
                        if (showPrivateLock) ...[
                          const SizedBox(height: 28),
                          Divider(
                              color: isDarkMode
                                  ? Colors.white12
                                  : Colors.black12),
                          const SizedBox(height: 24),
                          Icon(Icons.lock_outline, size: 52, color: subColor),
                          const SizedBox(height: 12),
                          Text('비공개 계정입니다',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            _hasPendingRequest
                                ? '요청이 수락되면 게시물을 볼 수 있습니다'
                                : '팔로우 요청을 보내면 게시물을 볼 수 있습니다',
                            style:
                                TextStyle(color: subColor, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),

                  // 게시물 섹션 (공개 계정이거나 팔로잉 중일 때)
                  if (!showPrivateLock) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.grid_on, size: 18, color: subColor),
                          const SizedBox(width: 8),
                          Text('게시물',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          if (!_loadingPosts) ...[
                            const SizedBox(width: 6),
                            Text('${_posts.length}',
                                style: TextStyle(color: subColor, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    if (_loadingPosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF00E676))),
                      )
                    else if (_posts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.photo_outlined,
                                  size: 48, color: subColor),
                              const SizedBox(height: 10),
                              Text('게시물이 없어요',
                                  style:
                                      TextStyle(color: subColor, fontSize: 14)),
                            ],
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final imageUrl = post['image_url'] != null
                              ? Supabase.instance.client.storage
                                  .from('posts')
                                  .getPublicUrl(post['image_url'] as String)
                              : null;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(
                                  post: post,
                                  isLiked: false,
                                  likeCount: 0,
                                ),
                              ),
                            ),
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, e, stack) => Container(
                                      color: isDarkMode
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey.shade200,
                                      child: Icon(Icons.image_outlined,
                                          color: subColor, size: 28),
                                    ),
                                  )
                                : Container(
                                    color: isDarkMode
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.grey.shade100,
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      post['content'] as String? ?? '',
                                      style: TextStyle(
                                          color: textColor, fontSize: 12),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
    );
  }
}

class _CountItem extends StatelessWidget {
  final String label;
  final int count;
  final Color textColor;
  final Color subTextColor;

  const _CountItem({
    required this.label,
    required this.count,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 13, color: subTextColor)),
      ],
    );
  }
}

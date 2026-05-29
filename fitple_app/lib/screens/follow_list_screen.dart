import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true=팔로워, false=팔로잉

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<Map<String, dynamic>> _users = [];
  // 내가 팔로잉 중인 유저 ID 세트 (버튼 상태용)
  Set<String> _myFollowingIds = {};
  bool _isLoading = true;
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() => _isLoading = true);
    try {
      // 팔로워 또는 팔로잉 목록 조회
      final List data;
      if (widget.isFollowers) {
        data = await Supabase.instance.client
            .from('follows')
            .select('follower_id, follower_nickname')
            .eq('following_id', widget.userId)
            .order('created_at', ascending: false);
      } else {
        data = await Supabase.instance.client
            .from('follows')
            .select('following_id, following_nickname')
            .eq('follower_id', widget.userId)
            .order('created_at', ascending: false);
      }

      // 내가 팔로잉 중인 ID 목록 (버튼 상태용)
      final myFollowing = await Supabase.instance.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', _currentUserId);

      final followingIds =
          (myFollowing as List).map((f) => f['following_id'] as String).toSet();

      if (mounted) {
        setState(() {
          _users = data.map((item) {
            if (widget.isFollowers) {
              return {
                'userId': item['follower_id'] as String,
                'nickname': item['follower_nickname'] as String? ?? '사용자',
              };
            } else {
              return {
                'userId': item['following_id'] as String,
                'nickname': item['following_nickname'] as String? ?? '사용자',
              };
            }
          }).toList();
          _myFollowingIds = followingIds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String targetId, String targetNickname) async {
    final isFollowing = _myFollowingIds.contains(targetId);
    // 낙관적 업데이트
    setState(() {
      if (isFollowing) {
        _myFollowingIds.remove(targetId);
      } else {
        _myFollowingIds.add(targetId);
      }
    });
    try {
      if (isFollowing) {
        await Supabase.instance.client
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId)
            .eq('following_id', targetId);
        // 팔로잉 목록에서 보이는 경우 행도 제거
        if (!widget.isFollowers && widget.userId == _currentUserId) {
          setState(() => _users.removeWhere((u) => u['userId'] == targetId));
        }
      } else {
        final myNickname =
            Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
                as String? ?? '사용자';
        await Supabase.instance.client.from('follows').insert({
          'follower_id': _currentUserId,
          'follower_nickname': myNickname,
          'following_id': targetId,
          'following_nickname': targetNickname,
        });
      }
    } catch (_) {
      // 롤백
      setState(() {
        if (isFollowing) {
          _myFollowingIds.add(targetId);
        } else {
          _myFollowingIds.remove(targetId);
        }
      });
    }
  }

  Future<void> _removeFollower(String followerId) async {
    // 내 팔로워 강제 삭제
    await Supabase.instance.client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', _currentUserId);
    setState(() => _users.removeWhere((u) => u['userId'] == followerId));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    final isMyProfile = widget.userId == _currentUserId;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.isFollowers ? '팔로워' : '팔로잉',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
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
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 56, color: subColor),
                      const SizedBox(height: 12),
                      Text(
                        widget.isFollowers ? '아직 팔로워가 없어요' : '팔로잉 중인 유저가 없어요',
                        style: TextStyle(color: subColor, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final uid = user['userId'] as String;
                    final nickname = user['nickname'] as String;
                    final isMe = uid == _currentUserId;
                    final amFollowing = _myFollowingIds.contains(uid);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      leading: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                                userId: uid, nickname: nickname),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              const Color(0xFF00E676).withValues(alpha: 0.2),
                          child: const Icon(Icons.person,
                              color: Color(0xFF00E676), size: 26),
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                                userId: uid, nickname: nickname),
                          ),
                        ),
                        child: Text(nickname,
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.w600)),
                      ),
                      trailing: isMe
                          ? null
                          : widget.isFollowers && isMyProfile
                              ? // 내 팔로워 → 삭제 버튼
                              TextButton(
                                  onPressed: () => _showRemoveDialog(uid, nickname),
                                  child: const Text('삭제',
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold)),
                                )
                              : // 팔로잉 목록 또는 다른 유저의 목록 → 팔로우/언팔로우
                              SizedBox(
                                  width: 90,
                                  height: 34,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _toggleFollow(uid, nickname),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: amFollowing
                                          ? Colors.transparent
                                          : const Color(0xFF00E676),
                                      side: BorderSide(
                                        color: amFollowing
                                            ? (isDarkMode
                                                ? Colors.white24
                                                : Colors.black26)
                                            : const Color(0xFF00E676),
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      amFollowing ? '팔로잉' : '팔로우',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: amFollowing
                                            ? subColor
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                    );
                  },
                ),
    );
  }

  void _showRemoveDialog(String uid, String nickname) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팔로워 삭제'),
        content: Text('$nickname 님을 팔로워 목록에서 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeFollower(uid);
            },
            child: const Text('삭제',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

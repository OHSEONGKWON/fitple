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
  bool _isLoading = true;
  bool _isMyProfile = false;

  @override
  void initState() {
    super.initState();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _isMyProfile = currentUserId != null && currentUserId == widget.userId;
    _loadList();
  }

  Future<void> _removeFollower(String followerUserId) async {
    try {
      final deleted = await Supabase.instance.client
          .from('follows')
          .delete()
          .eq('follower_id', followerUserId)
          .eq('following_id', widget.userId)
          .select();
      if (!mounted) return;
      if ((deleted as List).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 권한이 없습니다. Supabase RLS 정책을 확인해주세요.')),
        );
        return;
      }
      setState(() {
        _users.removeWhere((u) => u['userId'] == followerUserId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로워를 삭제했습니다.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했습니다: $e')),
        );
      }
    }
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
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;

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

                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: uid, nickname: nickname),
                        ),
                      ),
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
                      trailing: _isMyProfile && widget.isFollowers
                          ? IconButton(
                              icon: const Icon(Icons.person_remove_outlined,
                                  color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('팔로워 삭제'),
                                    content: Text(
                                        '$nickname님을 팔로워에서 삭제할까요?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('삭제',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _removeFollower(uid);
                                }
                              },
                            )
                          : Icon(Icons.chevron_right, color: subColor),
                    );
                  },
                ),
    );
  }
}

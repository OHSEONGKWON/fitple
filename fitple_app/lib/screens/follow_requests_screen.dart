import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_screen.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      final data = await Supabase.instance.client
          .from('follow_requests')
          .select()
          .eq('target_id', currentUser.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> request) async {
    final reqId = request['id'] as String;
    final requesterId = request['requester_id'] as String;
    final requesterNickname =
        request['requester_nickname'] as String? ?? '사용자';
    final currentUser = Supabase.instance.client.auth.currentUser!;
    final myNickname =
        currentUser.userMetadata?['display_name'] as String? ?? '사용자';

    setState(() => _processing.add(reqId));
    try {
      // follows 테이블에 추가 (닉네임 컬럼 있으면 포함, 없으면 기본만)
      try {
        await Supabase.instance.client.from('follows').insert({
          'follower_id': requesterId,
          'follower_nickname': requesterNickname,
          'following_id': currentUser.id,
          'following_nickname': myNickname,
        });
      } catch (_) {
        await Supabase.instance.client.from('follows').insert({
          'follower_id': requesterId,
          'following_id': currentUser.id,
        });
      }
      // 요청 삭제
      await Supabase.instance.client
          .from('follow_requests')
          .delete()
          .eq('id', reqId);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r['id'] == reqId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('팔로우 요청을 수락했습니다'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      if (mounted) setState(() => _processing.remove(reqId));
    }
  }

  Future<void> _reject(String reqId) async {
    setState(() => _processing.add(reqId));
    try {
      await Supabase.instance.client
          .from('follow_requests')
          .delete()
          .eq('id', reqId);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r['id'] == reqId));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _processing.remove(reqId));
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
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('팔로우 요청',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
          : RefreshIndicator(
              color: const Color(0xFF00E676),
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_outlined,
                                    size: 56, color: subColor),
                                const SizedBox(height: 12),
                                Text('받은 팔로우 요청이 없어요',
                                    style: TextStyle(
                                        color: subColor, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        final reqId = req['id'] as String;
                        final requesterId = req['requester_id'] as String;
                        final nickname =
                            req['requester_nickname'] as String? ?? '사용자';
                        final isProcessing = _processing.contains(reqId);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              if (!isDarkMode)
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                        userId: requesterId,
                                        nickname: nickname),
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF00E676)
                                      .withValues(alpha: 0.2),
                                  child: const Icon(Icons.person,
                                      color: Color(0xFF00E676), size: 26),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nickname,
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                      '팔로우를 요청했습니다 · ${_timeAgo(req['created_at'] as String?)}',
                                      style: TextStyle(
                                          color: subColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isProcessing)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00E676)),
                                )
                              else
                                Row(
                                  children: [
                                    // 수락
                                    SizedBox(
                                      width: 60,
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: () => _accept(req),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00E676),
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('수락',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 거절
                                    SizedBox(
                                      width: 60,
                                      height: 32,
                                      child: OutlinedButton(
                                        onPressed: () => _reject(reqId),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: isDarkMode
                                                  ? Colors.white24
                                                  : Colors.black26),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: Text('거절',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: subColor)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

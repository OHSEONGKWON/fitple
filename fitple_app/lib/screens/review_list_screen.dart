import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'review_write_screen.dart';

class ReviewListScreen extends StatefulWidget {
  final String gatheringId;
  final String gatheringTitle;

  const ReviewListScreen({
    super.key,
    required this.gatheringId,
    required this.gatheringTitle,
  });

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  bool _isLoading = true;
  final List<_ReviewTarget> _targets = [];
  final Set<String> _alreadyReviewed = {};

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _targets.clear();
        _alreadyReviewed.clear();
      });
    }

    try {
      final users = <String, String>{};

      final hostRows = await Supabase.instance.client
          .from('gatherings')
          .select('user_id, user_nickname')
          .eq('id', widget.gatheringId)
          .limit(1);
      if (hostRows.isNotEmpty) {
        final host = hostRows.first;
        final hostId = (host['user_id'] ?? '').toString();
        final hostName = (host['user_nickname'] ?? '호스트').toString();
        if (hostId.isNotEmpty) users[hostId] = hostName;
      }

      final rooms = await Supabase.instance.client
          .from('chat_rooms')
          .select('host_id, host_nickname, guest_id, guest_nickname')
          .eq('gathering_id', widget.gatheringId);

      for (final row in rooms) {
        final hostId = (row['host_id'] ?? '').toString();
        final hostName = (row['host_nickname'] ?? '호스트').toString();
        if (hostId.isNotEmpty) users.putIfAbsent(hostId, () => hostName);

        final guestId = (row['guest_id'] ?? '').toString();
        final guestName = (row['guest_nickname'] ?? '참여자').toString();
        if (guestId.isNotEmpty) users.putIfAbsent(guestId, () => guestName);
      }

      final groupRoom = await Supabase.instance.client
          .from('group_chat_rooms')
          .select('id')
          .eq('gathering_id', widget.gatheringId)
          .maybeSingle();

      if (groupRoom != null) {
        final roomId = groupRoom['id'] as String;
        final groupMessages = await Supabase.instance.client
            .from('group_messages')
            .select('user_id, user_nickname')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(500);

        for (final row in groupMessages) {
          final userId = (row['user_id'] ?? '').toString();
          final nickname = (row['user_nickname'] ?? '참여자').toString();
          if (userId.isNotEmpty) users.putIfAbsent(userId, () => nickname);
        }
      }

      users.remove(_myId);

      final myReviews = await Supabase.instance.client
          .from('user_reviews')
          .select('reviewee_id')
          .eq('gathering_id', widget.gatheringId)
          .eq('reviewer_id', _myId);

      for (final row in myReviews) {
        final revieweeId = (row['reviewee_id'] ?? '').toString();
        if (revieweeId.isNotEmpty) _alreadyReviewed.add(revieweeId);
      }

      final targets = users.entries
          .map((e) => _ReviewTarget(userId: e.key, nickname: e.value))
          .toList()
        ..sort((a, b) => a.nickname.compareTo(b.nickname));

      if (!mounted) return;
      setState(() {
        _targets.addAll(targets);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('평가 대상 불러오기 실패: $e')),
      );
    }
  }

  Future<void> _goReview(_ReviewTarget target) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewWriteScreen(
          gatheringId: widget.gatheringId,
          revieweeId: target.userId,
          revieweeNickname: target.nickname,
        ),
      ),
    );

    if (result == true) {
      await _loadTargets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '참여자 평가',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.gatheringTitle,
              style: TextStyle(color: subColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : _targets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '평가 가능한 참여자가 아직 없어요.\n채팅 참여 후 다시 시도해보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subColor, fontSize: 14, height: 1.6),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTargets,
                  color: const Color(0xFF00E676),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: _targets.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final target = _targets[index];
                      final reviewed = _alreadyReviewed.contains(target.userId);

                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDarkMode ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.18),
                            child: const Icon(Icons.person, color: Color(0xFF00E676)),
                          ),
                          title: Text(
                            target.nickname,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            reviewed ? '평가 완료' : '아직 평가하지 않았어요',
                            style: TextStyle(color: reviewed ? const Color(0xFF00E676) : subColor),
                          ),
                          trailing: ElevatedButton(
                            onPressed: reviewed ? null : () => _goReview(target),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: reviewed
                                  ? (isDarkMode ? Colors.white12 : Colors.grey.shade200)
                                  : const Color(0xFF00E676),
                              foregroundColor: reviewed ? subColor : Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              reviewed ? '완료' : '평가하기',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ReviewTarget {
  final String userId;
  final String nickname;

  const _ReviewTarget({required this.userId, required this.nickname});
}

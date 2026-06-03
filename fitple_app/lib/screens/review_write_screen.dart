import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 온도 변화량 계산
double _calcDelta(int rating, List<String> positiveTags, List<String> negativeTags) {
  // 별점 기여: 5→+1.0, 4→+0.5, 3→0, 2→-0.5, 1→-1.0
  final ratingDelta = (rating - 3) * 0.5;
  final tagDelta = positiveTags.length * 0.1 - negativeTags.length * 0.15;
  return double.parse((ratingDelta + tagDelta).clamp(-3.0, 3.0).toStringAsFixed(2));
}

class ReviewWriteScreen extends StatefulWidget {
  final String gatheringId;
  final String revieweeId;
  final String revieweeNickname;

  const ReviewWriteScreen({
    super.key,
    required this.gatheringId,
    required this.revieweeId,
    required this.revieweeNickname,
  });

  @override
  State<ReviewWriteScreen> createState() => _ReviewWriteScreenState();
}

class _ReviewWriteScreenState extends State<ReviewWriteScreen> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  final Set<String> _positiveTags = {};
  final Set<String> _negativeTags = {};
  bool _isSubmitting = false;
  static const int _maxPositiveTags = 3;
  static const int _maxNegativeTags = 2;

  static const _posTags = [
    ('운동을 잘해요', '💪'),
    ('매너가 좋아요', '😊'),
    ('시간약속 칼같아요', '⏰'),
    ('또 같이 하고 싶어요', '🔥'),
    ('친절하고 배려있어요', '😄'),
    ('열정이 넘쳐요', '⚡'),
  ];

  static const _negTags = [
    ('매너가 아쉬워요', '😞'),
    ('시간약속을 안 지켜요', '⏱'),
    ('연락이 잘 안 돼요', '📵'),
    ('실력 차이가 너무 심해요', '🎯'),
  ];

  double get _delta => _calcDelta(_rating, _positiveTags.toList(), _negativeTags.toList());

  Color get _tempColor {
    if (_delta >= 0.5) return const Color(0xFFFF5722);
    if (_delta >= 0.1) return const Color(0xFF00E676);
    if (_delta > -0.1) return Colors.grey;
    return Colors.blue;
  }

  void _togglePositiveTag(String tag) {
    setState(() {
      if (_positiveTags.contains(tag)) {
        _positiveTags.remove(tag);
        return;
      }
      if (_positiveTags.length >= _maxPositiveTags) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('좋았던 점은 최대 3개까지 선택할 수 있어요.')),
        );
        return;
      }
      _positiveTags.add(tag);
    });
  }

  void _toggleNegativeTag(String tag) {
    setState(() {
      if (_negativeTags.contains(tag)) {
        _negativeTags.remove(tag);
        return;
      }
      if (_negativeTags.length >= _maxNegativeTags) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아쉬웠던 점은 최대 2개까지 선택할 수 있어요.')),
        );
        return;
      }
      _negativeTags.add(tag);
    });
  }

  Future<bool> _isParticipant(String userId) async {
    final host = await Supabase.instance.client
        .from('gatherings')
        .select('user_id')
        .eq('id', widget.gatheringId)
        .limit(1);
    if (host.isNotEmpty) {
      final hostId = (host.first['user_id'] ?? '').toString();
      if (hostId == userId) return true;
    }

    final roomRows = await Supabase.instance.client
        .from('chat_rooms')
        .select('id')
        .eq('gathering_id', widget.gatheringId)
        .or('host_id.eq.$userId,guest_id.eq.$userId')
        .limit(1);
    if (roomRows.isNotEmpty) return true;

    final groupRoom = await Supabase.instance.client
        .from('group_chat_rooms')
        .select('id')
        .eq('gathering_id', widget.gatheringId)
        .maybeSingle();
    if (groupRoom == null) return false;

    final roomId = (groupRoom['id'] ?? '').toString();
    if (roomId.isEmpty) return false;

    final msgRows = await Supabase.instance.client
        .from('group_messages')
        .select('id')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .limit(1);
    return msgRows.isNotEmpty;
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (user.id == widget.revieweeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인에게는 후기를 남길 수 없어요.')),
      );
      return;
    }

    try {
      final reviewerParticipated = await _isParticipant(user.id);
      final revieweeParticipated = await _isParticipant(widget.revieweeId);
      if (!reviewerParticipated || !revieweeParticipated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내가 참여한 경기의 참가자만 평가할 수 있어요.')),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('참여 여부 확인 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final delta = _delta;

      // 후기 저장
      await Supabase.instance.client.from('user_reviews').insert({
        'gathering_id': widget.gatheringId,
        'reviewer_id': user.id,
        'reviewee_id': widget.revieweeId,
        'rating': _rating,
        'positive_tags': _positiveTags.toList(),
        'negative_tags': _negativeTags.toList(),
        'comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        'temperature_delta': delta,
      });

      // 온도 업데이트
      final existing = await Supabase.instance.client
          .from('user_temperature')
          .select()
          .eq('user_id', widget.revieweeId)
          .maybeSingle();

      if (existing != null) {
        final currentTemp = (existing['temperature'] as num).toDouble();
        final newTemp = (currentTemp + delta).clamp(0.0, 100.0);
        await Supabase.instance.client.from('user_temperature').update({
          'temperature': double.parse(newTemp.toStringAsFixed(1)),
          'review_count': (existing['review_count'] as int) + 1,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', widget.revieweeId);
      } else {
        final newTemp = (36.5 + delta).clamp(0.0, 100.0);
        await Supabase.instance.client.from('user_temperature').insert({
          'user_id': widget.revieweeId,
          'temperature': double.parse(newTemp.toStringAsFixed(1)),
          'review_count': 1,
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final missingReviewTable =
          e.code == 'PGRST205' && e.message.contains("public.user_reviews");
      final missingTempTable =
          e.code == 'PGRST205' && e.message.contains("public.user_temperature");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (missingReviewTable || missingTempTable)
                ? '평가 DB 테이블이 아직 생성되지 않았어요. Supabase SQL Editor에서 supabase_reviews.sql을 먼저 실행해주세요.'
                : '후기 등록 실패: ${e.message}',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('후기 등록 실패: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final divColor = isDarkMode ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('후기 남기기',
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00E676)))
                  : const Text('완료',
                      style: TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 상대방 이름 + 온도 미리보기 ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        const Color(0xFF00E676).withValues(alpha: 0.2),
                    child: const Icon(Icons.person,
                        color: Color(0xFF00E676), size: 36),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.revieweeNickname,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('님과의 경기는 어땠나요?',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 16),
                  // 온도 변화 미리보기
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _tempColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _tempColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _delta >= 0 ? Icons.local_fire_department : Icons.ac_unit,
                          color: _tempColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _delta >= 0
                              ? '+${_delta.toStringAsFixed(1)}°C 예상'
                              : '${_delta.toStringAsFixed(1)}°C 예상',
                          style: TextStyle(
                              color: _tempColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '좋았던 점 ${_positiveTags.length}/$_maxPositiveTags · 아쉬웠던 점 ${_negativeTags.length}/$_maxNegativeTags',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 8, color: divColor),

            // ── 별점 ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('전반적인 평가',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = star),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            _rating >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: _rating >= star
                                ? const Color(0xFFFFB300)
                                : Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      ['', '별로예요', '아쉬워요', '보통이에요', '좋아요', '최고예요'][_rating],
                      style: TextStyle(
                          color: subColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 8, color: divColor),

            // ── 긍정 태그 ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.local_fire_department,
                        color: Color(0xFF00E676), size: 18),
                    const SizedBox(width: 6),
                    Text('이런 점이 좋았어요',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('최대 $_maxPositiveTags개',
                      style: TextStyle(color: subColor, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _posTags.map((tag) {
                      final selected = _positiveTags.contains(tag.$1);
                      return GestureDetector(
                        onTap: () => _togglePositiveTag(tag.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                                : (isDarkMode
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF00E676)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${tag.$2} ${tag.$1}',
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF00E676)
                                  : subColor,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Divider(height: 8, color: divColor),

            // ── 부정 태그 ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.ac_unit, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    Text('아쉬웠던 점이 있어요',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text('최대 $_maxNegativeTags개',
                        style: TextStyle(color: subColor, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _negTags.map((tag) {
                      final selected = _negativeTags.contains(tag.$1);
                      return GestureDetector(
                        onTap: () => _toggleNegativeTag(tag.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.blueAccent.withValues(alpha: 0.12)
                                : (isDarkMode
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Colors.blueAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${tag.$2} ${tag.$1}',
                            style: TextStyle(
                              color: selected ? Colors.blueAccent : subColor,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Divider(height: 8, color: divColor),

            // ── 코멘트 ──
            Container(
              color: cardColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('한마디 남기기',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('선택 사항이에요',
                      style: TextStyle(color: subColor, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    maxLength: 200,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '경기 후기를 자유롭게 남겨주세요...',
                      hintStyle: TextStyle(color: subColor),
                      filled: true,
                      fillColor: isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle:
                          TextStyle(color: subColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

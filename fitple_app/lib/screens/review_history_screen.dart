import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewHistoryScreen extends StatefulWidget {
  final String userId;
  final String nickname;

  const ReviewHistoryScreen({
    super.key,
    required this.userId,
    required this.nickname,
  });

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  bool _isLoading = true;
  String? _schemaErrorMessage;
  final List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _schemaErrorMessage = null;
        _reviews.clear();
      });
    }

    try {
      final rows = await Supabase.instance.client
          .from('user_reviews')
          .select(
              'id, gathering_id, reviewer_id, rating, positive_tags, negative_tags, comment, temperature_delta, created_at')
          .eq('reviewee_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(200);

      if (!mounted) return;
      setState(() {
        _reviews.addAll(List<Map<String, dynamic>>.from(rows));
        _isLoading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final missingTable =
          e.code == 'PGRST205' && e.message.contains('public.user_reviews');
      setState(() {
        _isLoading = false;
        if (missingTable) {
          _schemaErrorMessage =
              '평가 테이블이 아직 생성되지 않았어요.\nSupabase SQL Editor에서 supabase_reviews.sql을 실행해주세요.';
        }
      });
      if (!missingTable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 불러오기 실패: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리뷰 불러오기 실패: $e')),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  List<String> _toTagList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: const Color(0xFFFFC107),
        );
      }),
    );
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
              '${widget.nickname}님의 리뷰',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              '총 ${_reviews.length}개',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : _schemaErrorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _schemaErrorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subColor, fontSize: 14, height: 1.6),
                    ),
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Text(
                        '아직 등록된 리뷰가 없어요.',
                        style: TextStyle(color: subColor, fontSize: 14),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      color: const Color(0xFF00E676),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: _reviews.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = _reviews[index];
                          final rating = (row['rating'] as num?)?.toInt() ?? 0;
                          final delta = (row['temperature_delta'] as num?)?.toDouble() ?? 0;
                          final comment = (row['comment'] ?? '').toString().trim();
                          final positiveTags = _toTagList(row['positive_tags']);
                          final negativeTags = _toTagList(row['negative_tags']);
                          final reviewerId = (row['reviewer_id'] ?? '').toString();
                          final reviewerText = reviewerId.isEmpty
                              ? '리뷰어'
                              : '리뷰어 ${reviewerId.substring(0, reviewerId.length >= 8 ? 8 : reviewerId.length)}';

                          return Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDarkMode ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildStars(rating),
                                    const SizedBox(width: 8),
                                    Text(
                                      reviewerText,
                                      style: TextStyle(
                                        color: subColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(row['created_at']?.toString()),
                                      style: TextStyle(color: subColor, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  delta >= 0
                                      ? '온도 +${delta.toStringAsFixed(1)}°C'
                                      : '온도 ${delta.toStringAsFixed(1)}°C',
                                  style: TextStyle(
                                    color: delta >= 0
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFF42A5F5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (positiveTags.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: positiveTags
                                        .map(
                                          (tag) => Chip(
                                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                            side: BorderSide.none,
                                            backgroundColor: const Color(0xFF00E676)
                                                .withValues(alpha: 0.15),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                if (negativeTags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: negativeTags
                                        .map(
                                          (tag) => Chip(
                                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                                            visualDensity: VisualDensity.compact,
                                            side: BorderSide.none,
                                            backgroundColor: Colors.redAccent
                                                .withValues(alpha: 0.14),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    comment,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

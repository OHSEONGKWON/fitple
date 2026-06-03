import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gather_edit_screen.dart';
import 'chat_room_screen.dart';
import 'user_profile_screen.dart';
import 'group_chat_screen.dart';
import 'review_list_screen.dart';
import '../services/geocoding_service.dart';

class GatherScreen extends StatefulWidget {
  const GatherScreen({super.key});

  @override
  State<GatherScreen> createState() => _GatherScreenState();
}

class _GatherScreenState extends State<GatherScreen> {
  String _currentSort = '최신순';
  String _searchQuery = '';
  String _selectedCategory = '전체';
  List<Map<String, dynamic>> _gatherings = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _locationCache = {};

  static const _categories = ['전체', '러닝', '축구', '족구', '배구', '배드민턴', '헬스'];

  @override
  void initState() {
    super.initState();
    _loadGatherings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGatherings() async {
    setState(() => _isLoading = true);
    try {
      final String orderColumn;
      final bool ascending;
      switch (_currentSort) {
        case '인기순':
          orderColumn = 'current_members';
          ascending = false;
          break;
        case '오래된순':
          orderColumn = 'created_at';
          ascending = true;
          break;
        case 'A-Z 순':
          orderColumn = 'title';
          ascending = true;
          break;
        default:
          orderColumn = 'created_at';
          ascending = false;
      }
      final data = await Supabase.instance.client
          .from('gatherings')
          .select()
          .order(orderColumn, ascending: ascending);
      final normalized = await _attachDisplayLocation(
        List<Map<String, dynamic>>.from(data),
      );
      if (mounted) {
        setState(() {
          _gatherings = normalized;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('불러오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteGathering(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모집글 삭제'),
        content: const Text('이 모집글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // 모집글 삭제 전에 채팅방이 모집글 FK/연결로 같이 지워지지 않도록 분리합니다.
      await Supabase.instance.client
          .from('chat_rooms')
          .update({
            'gathering_id': null,
            'gathering_title': '[삭제된 모집글]',
          })
          .eq('gathering_id', id);

      await Supabase.instance.client
          .from('group_chat_rooms')
          .update({
            'gathering_id': null,
            'gathering_title': '[삭제된 모집글]',
          })
          .eq('gathering_id', id);

      await Supabase.instance.client.from('gatherings').delete().eq('id', id);
      _loadGatherings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _toggleClosed(String id, bool isClosed) async {
    try {
      await Supabase.instance.client
          .from('gatherings')
          .update({'is_closed': !isClosed})
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!isClosed ? '모집이 마감되었습니다.' : '모집을 다시 열었습니다.')),
        );
      }
      _loadGatherings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마감 상태 변경 실패: $e')),
        );
      }
    }
  }

  String _formatTimeAgo(String createdAt) {
    final created = DateTime.parse(createdAt).toLocal();
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _formatDateRange(String start, String end) {
    final s = DateTime.parse(start);
    final e = DateTime.parse(end);
    return '${s.year}.${s.month.toString().padLeft(2, '0')}.${s.day.toString().padLeft(2, '0')} '
        '~ ${e.year}.${e.month.toString().padLeft(2, '0')}.${e.day.toString().padLeft(2, '0')}';
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '러닝': return Colors.redAccent;
      case '축구': return Colors.green;
      case '족구': return Colors.orange;
      case '배구': return Colors.blue;
      case '배드민턴': return Colors.purple;
      case '헬스': return Colors.teal;
      default: return Colors.blueGrey;
    }
  }

  String _displayLocation(dynamic rawLocation) {
    final location = (rawLocation ?? '').toString().trim();
    if (location.isEmpty || RegExp(r'^\d{5}$').hasMatch(location)) {
      return '지역 비공개';
    }
    return location;
  }

  Future<List<Map<String, dynamic>>> _attachDisplayLocation(
    List<Map<String, dynamic>> gatherings,
  ) async {
    return Future.wait(
      gatherings.map((g) async {
        final row = Map<String, dynamic>.from(g);
        row['display_location'] = await _resolveDisplayLocation(row);
        return row;
      }),
    );
  }

  Future<String> _resolveDisplayLocation(Map<String, dynamic> row) async {
    final rawLocation = (row['location'] ?? '').toString().trim();
    if (rawLocation.isEmpty || RegExp(r'^\d{5}$').hasMatch(rawLocation)) {
      return '지역 비공개';
    }

    NLatLng? latLng;
    final lat = double.tryParse((row['location_lat'] ?? '').toString());
    final lng = double.tryParse((row['location_lng'] ?? '').toString());
    if (lat != null && lng != null) {
      latLng = NLatLng(lat, lng);
    } else {
      latLng = GeocodingService.tryParseLatLngText(rawLocation);
    }

    if (latLng == null) {
      return rawLocation;
    }

    final key =
        '${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}';
    final cached = _locationCache[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final address = await GeocodingService.reverseGeocode(latLng);
    _locationCache[key] = address;
    return address;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100];

    final filtered = _gatherings.where((g) {
      final matchCat = _selectedCategory == '전체' || g['category'] == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          (g['title'] ?? '').toLowerCase().contains(q) ||
          (g['description'] ?? '').toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Stack(
      children: [
        SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 새로운 크루 모집하기
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        //color: cardColor, 박스 살리고 싶음 이거 지우면 됨
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.people_alt_outlined, color: Color(0xFF00E676), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('새로운 크루 모집하기',
                                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('함께 땀 흘릴 메이트를 찾아보세요',
                                    style: TextStyle(color: subTextColor, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (kIsWeb) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('웹에서는 간소화된 모집 작성 화면으로 이동합니다.')),
                                );
                              }
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GatherEditScreen(),
                                ),
                              );
                              if (result == true) _loadGatherings();
                            },
                            icon: const Icon(Icons.add_circle_outlined),
                            iconSize: 35,
                            color: const Color(0xFF00E676).withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
            
                    // 검색바
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '모집글 검색...',
                          hintStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.search, color: subTextColor, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: subTextColor, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
            
                    // 카테고리 필터 칩
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF00E676) : cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF00E676)
                                      : (isDarkMode ? Colors.white24 : Colors.black12),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : subTextColor,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
            
                    // 실시간 모집 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('실시간 모집 ✨',
                            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                        PopupMenuButton<String>(
                          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          position: PopupMenuPosition.under,
                          onSelected: (value) {
                            setState(() => _currentSort = value);
                            _loadGatherings();
                          },
                          itemBuilder: (ctx) => ['최신순', '오래된순', '인기순', 'A-Z 순'].map((choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(
                                choice,
                                style: TextStyle(
                                  color: _currentSort == choice ? const Color(0xFF00E676) : textColor,
                                  fontWeight: _currentSort == choice ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(_currentSort, style: TextStyle(color: subTextColor, fontSize: 13)),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, color: subTextColor, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
            
                    // 모집 리스트
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                    else if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            _gatherings.isEmpty
                                ? '아직 모집글이 없어요.\n첫 번째로 크루를 모집해보세요! 🏃'
                                : '검색 결과가 없어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 15, height: 1.6),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((g) => RecruitmentCard(
                              isDarkMode: isDarkMode,
                              accentColor: _categoryColor(g['category'] ?? '기타'),
                              category: g['category'] ?? '기타',
                              timeAgo: _formatTimeAgo(
                                  g['created_at'] ?? DateTime.now().toIso8601String()),
                              currentMembers: (g['current_members'] ?? 0) as int,
                              maxMembers: (g['max_members'] ?? 1) as int,
                              isClosed: (g['is_closed'] ?? false) as bool,
                              title: g['title'] ?? '',
                              description: g['description'] ?? '',
                              gatherDate: _formatDateRange(g['gather_start'], g['gather_end']),
                              userName: g['user_nickname'] ?? '알 수 없음',
                              userScore: '',
                              userBadge: '',
                              extraInfoIcon: Icons.location_on_outlined,
                                extraInfoText: (g['display_location'] ?? '').toString().trim().isEmpty
                                  ? _displayLocation(g['location'])
                                  : (g['display_location'] as String),
                              gatheringId: g['id'],
                              authorId: g['user_id'],
                              hostNickname: g['user_nickname'] ?? '익명',
                              gatheringTitle: g['title'] ?? '',
                              onEdit: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GatherEditScreen(initialData: g),
                                  ),
                                );
                                if (result == true) _loadGatherings();
                              },
                              onDelete: () => _deleteGathering(g['id']),
                              onToggleClosed: () =>
                                  _toggleClosed(g['id'], (g['is_closed'] ?? false) as bool),
                            )),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          Positioned(
        bottom: 12, 
        right: 20,  
        child: SizedBox(
          height: 45,
          child: FloatingActionButton.extended(
            onPressed: () async {
              if (kIsWeb) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('웹에서는 간소화된 모집 작성 화면으로 이동합니다.')),
                );
              }
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const GatherEditScreen(),
                ),
              );
              if (result == true) _loadGatherings();
            },
            
            // 디자인 커스텀 (당근마켓 스타일 + Fitple 브랜드 컬러)
            backgroundColor: const Color(0xFF00E676), // Fitple 시그니처 초록색
            foregroundColor: Colors.black,            // 글자 및 아이콘 색상 (검은색/어두운색 추천)
            elevation: 6,                             
            
            // 테두리를 당근마켓처럼 길쭉한 타원형(Capsule) 모양으로 만들기
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            
            // 아이콘과 텍스트 구성
            icon: const Icon(Icons.add, size: 22, fontWeight: FontWeight.bold),
            label: const Text(
              "모집하기",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5, // 자간을 살짝 좁혀서 더 트렌디하게
              ),
            ),
          ),
        ),
      ),
      ],
      ),
    );
  }
}

class RecruitmentCard extends StatefulWidget {
  final bool isDarkMode;
  final Color accentColor;
  final String category;
  final String timeAgo;
  final int currentMembers;
  final int maxMembers;
  final bool isClosed;
  final String title;
  final String description;
  final String gatherDate;
  final String userName;
  final String userScore;
  final String userBadge;
  final IconData extraInfoIcon;
  final String extraInfoText;
  final String gatheringId;
  final String authorId;
  final String hostNickname;
  final String gatheringTitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleClosed;

  const RecruitmentCard({
    super.key,
    required this.isDarkMode,
    required this.accentColor,
    required this.category,
    required this.timeAgo,
    required this.currentMembers,
    required this.maxMembers,
    required this.isClosed,
    required this.title,
    required this.description,
    required this.gatherDate,
    required this.userName,
    required this.userScore,
    required this.userBadge,
    required this.extraInfoIcon,
    required this.extraInfoText,
    required this.gatheringId,
    required this.authorId,
    required this.hostNickname,
    required this.gatheringTitle,
    this.onEdit,
    this.onDelete,
    this.onToggleClosed,
  });

  @override
  State<RecruitmentCard> createState() => _RecruitmentCardState();
}

class _RecruitmentCardState extends State<RecruitmentCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '축구':
        return Icons.sports_soccer;
      case '족구':
      case '배구':
        return Icons.sports_volleyball;
      case '배드민턴':
        return Icons.sports_tennis;
      case '헬스':
        return Icons.fitness_center;
      case '러닝':
        return Icons.directions_run;
      default:
        return Icons.sports;
    }
  }

  Future<void> _openReviewList() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewListScreen(
          gatheringId: widget.gatheringId,
          gatheringTitle: widget.gatheringTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subTextColor = widget.isDarkMode ? Colors.white54 : Colors.black54;
    final dividerColor = widget.isDarkMode ? Colors.white12 : Colors.black12;
    final thumbBgColor = widget.isClosed
        ? (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[200]!)
        : (widget.isDarkMode
            ? widget.accentColor.withValues(alpha: 0.25)
            : widget.accentColor.withValues(alpha: 0.12));
    final isAuthor =
        Supabase.instance.client.auth.currentUser?.id == widget.authorId;

    return Column(
      children: [
        // ── Tappable summary row ──────────────────────────────────────────
        GestureDetector(
          onTap: _toggleExpand,
          child: Container(
            color: bgColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left thumbnail 80×80
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: thumbBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _categoryIcon(widget.category),
                        color: widget.isClosed
                            ? Colors.grey
                            : widget.accentColor,
                        size: 36,
                      ),
                    ),
                    if (widget.isClosed)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '마감',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Right info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + popup menu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                color: widget.isClosed
                                    ? subTextColor
                                    : textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAuthor)
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    color: subTextColor, size: 16),
                                color: widget.isDarkMode
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    widget.onEdit?.call();
                                  }
                                  if (value == 'delete') {
                                    widget.onDelete?.call();
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined,
                                          size: 18,
                                          color: widget.isDarkMode
                                              ? Colors.white70
                                              : Colors.black87),
                                      const SizedBox(width: 8),
                                      const Text('수정'),
                                    ]),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red),
                                      const SizedBox(width: 8),
                                      const Text('삭제',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Category · location · timeAgo
                      Row(
                        children: [
                          Text(
                            widget.category,
                            style: TextStyle(
                                color: subTextColor, fontSize: 12),
                          ),
                          Text(' · ',
                              style: TextStyle(
                                  color: subTextColor, fontSize: 12)),
                          Icon(Icons.location_on_outlined,
                              color: subTextColor, size: 12),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              widget.extraInfoText,
                              style: TextStyle(
                                  color: subTextColor, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(' · ',
                              style: TextStyle(
                                  color: subTextColor, fontSize: 12)),
                          Text(
                            widget.timeAgo,
                            style: TextStyle(
                                color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // Member count + progress bar
                      Row(
                        children: [
                          Icon(Icons.people_outline,
                              color: subTextColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.currentMembers}/${widget.maxMembers}명',
                            style: TextStyle(
                              color: widget.isClosed
                                  ? subTextColor
                                  : widget.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: widget.maxMembers > 0
                                    ? (widget.currentMembers /
                                            widget.maxMembers)
                                        .clamp(0.0, 1.0)
                                    : 0,
                                backgroundColor: widget.isDarkMode
                                    ? Colors.white12
                                    : Colors.grey[200],
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  widget.isClosed
                                      ? Colors.grey
                                      : widget.accentColor,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // Author row
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: widget.authorId,
                              nickname: widget.userName,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: widget.isDarkMode
                                  ? const Color(0xFF2C2C2C)
                                  : Colors.grey[300],
                              child: Icon(Icons.person,
                                  color: subTextColor, size: 13),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.userName,
                              style: TextStyle(
                                  color: subTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand arrow
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: subTextColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expandable detail section ─────────────────────────────────────
        SizeTransition(
          sizeFactor: _animation,
          axisAlignment: -1.0,
          child: Container(
            color: bgColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: dividerColor),
                const SizedBox(height: 12),

                // 모집 날짜
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: subTextColor, size: 16),
                    const SizedBox(width: 8),
                    Text('모집 기간: ',
                        style: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(widget.gatherDate,
                          style:
                              TextStyle(color: textColor, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 본문
                Text(widget.description,
                    style: TextStyle(
                        color: textColor, fontSize: 14, height: 1.5)),
                const SizedBox(height: 14),

                // 채팅하기 (비작성자) or 마감하기/재모집 (작성자)
                if (isAuthor) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onToggleClosed,
                        icon: Icon(
                          widget.isClosed
                              ? Icons.refresh_rounded
                              : Icons.block_rounded,
                          size: 18,
                          color: widget.isClosed
                              ? const Color(0xFF00E676)
                              : Colors.red,
                        ),
                        label: Text(
                          widget.isClosed ? '재모집하기' : '모집 마감하기',
                          style: TextStyle(
                            color: widget.isClosed
                                ? const Color(0xFF00E676)
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: widget.isClosed
                                  ? const Color(0xFF00E676)
                                  : Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupChatScreen(
                              gatheringId: widget.gatheringId,
                              gatheringTitle: widget.gatheringTitle,
                              hostId: widget.authorId,
                              hostNickname: widget.hostNickname,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.forum_outlined,
                            size: 18, color: Colors.black),
                        label: const Text('팀 채팅하기',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ]
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.isClosed
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? Colors.white12
                                    : Colors.grey[200],
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('모집이 마감되었어요',
                                    style: TextStyle(
                                        color: subTextColor,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            )
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final currentUser = Supabase
                                          .instance
                                          .client
                                          .auth
                                          .currentUser;
                                      if (currentUser == null) {
                                        return;
                                      }
                                      try {
                                        final existing =
                                            await Supabase
                                                .instance.client
                                                .from('chat_rooms')
                                                .select()
                                                .eq('gathering_id',
                                                    widget.gatheringId)
                                                .eq('guest_id',
                                                    currentUser.id)
                                                .maybeSingle();

                                        String roomId;
                                        if (existing != null) {
                                          roomId = existing['id'];
                                        } else {
                                          final created =
                                              await Supabase
                                                  .instance.client
                                                  .from('chat_rooms')
                                                  .insert({
                                                    'gathering_id':
                                                        widget
                                                            .gatheringId,
                                                    'gathering_title':
                                                        widget
                                                            .gatheringTitle,
                                                    'host_id':
                                                        widget.authorId,
                                                    'host_nickname':
                                                        widget
                                                            .hostNickname,
                                                    'guest_id':
                                                        currentUser.id,
                                                    'guest_nickname':
                                                        currentUser
                                                                .userMetadata?[
                                                                    'display_name'] ??
                                                            currentUser
                                                                .email ??
                                                            '익명',
                                                  })
                                                  .select()
                                                  .single();
                                          roomId = created['id'];
                                        }
                                        if (!context.mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ChatRoomScreen(
                                              roomId: roomId,
                                              otherUserNickname:
                                                  widget.hostNickname,
                                              gatheringTitle:
                                                  widget.gatheringTitle,
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      '채팅 시작 실패: $e')));
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18,
                                        color: Colors.black),
                                    label: const Text('팀장과 채팅하기',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight:
                                                FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF00E676),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12)),
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 단체채팅
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupChatScreen(
                                          gatheringId: widget.gatheringId,
                                          gatheringTitle: widget.gatheringTitle,
                                          hostId: widget.authorId,
                                          hostNickname: widget.hostNickname,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.forum_outlined,
                                        size: 18, color: Colors.black),
                                    label: const Text('팀 채팅하기',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openReviewList,
                      icon: const Icon(
                        Icons.reviews_outlined,
                        size: 18,
                        color: Color(0xFF00E676),
                      ),
                      label: const Text(
                        '참여자 평가하기',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E676)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Divider(height: 1, color: dividerColor),
      ],
    );
  }
}

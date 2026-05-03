import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gather_edit_screen.dart';
import 'chat_room_screen.dart';

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
      if (mounted) {
        setState(() {
          _gatherings = List<Map<String, dynamic>>.from(data);
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
    // 현재는 모집 마감 시 삭제하는 방식으로 처리합니다.
    if (isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재모집 기능은 현재 지원되지 않습니다.')),
        );
      }
      return;
    }
    await _deleteGathering(id);
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 새로운 크루 모집하기
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
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
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GatherEditScreen(),
                          fullscreenDialog: true,
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
              ...filtered.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RecruitmentCard(
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
                      extraInfoText: _displayLocation(g['location']),
                      gatheringId: g['id'],
                      authorId: g['user_id'],
                      hostNickname: g['user_nickname'] ?? '익명',
                      gatheringTitle: g['title'] ?? '',
                      onEdit: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GatherEditScreen(initialData: g),
                            fullscreenDialog: true,
                          ),
                        );
                        if (result == true) _loadGatherings();
                      },
                      onDelete: () => _deleteGathering(g['id']),
                      onToggleClosed: () =>
                          _toggleClosed(g['id'], (g['is_closed'] ?? false) as bool),
                    ),
                  )),
            const SizedBox(height: 100),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subTextColor = widget.isDarkMode ? Colors.white54 : Colors.black54;
    final isAuthor =
        Supabase.instance.client.auth.currentUser?.id == widget.authorId;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: widget.isClosed
                        ? Colors.grey
                        : widget.accentColor,
                    width: 6)),
          ),
          padding: const EdgeInsets.only(top: 18, left: 20, right: 20, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 카테고리 + 마감 배지 + 시간 + 더보기
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (widget.isClosed ? Colors.grey : widget.accentColor)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: (widget.isClosed ? Colors.grey : widget.accentColor)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Text(widget.category,
                        style: TextStyle(
                            color: widget.isClosed ? Colors.grey : widget.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (widget.isClosed) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                      ),
                      child: const Text('마감',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(widget.timeAgo,
                      style: TextStyle(color: subTextColor, fontSize: 12)),
                  const Spacer(),
                  if (isAuthor)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subTextColor, size: 18),
                      color: widget.isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'delete') widget.onDelete?.call();
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
                            const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('삭제',
                                style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. 제목
              Text(widget.title,
                  style: TextStyle(
                      color: widget.isClosed ? subTextColor : textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // 3. 유저 정보 + 위치
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.grey[300],
                    child: Icon(Icons.person, color: subTextColor, size: 20), //나중에 사용자 프로필 사진으로 바꿔야함
                  ),
                  const SizedBox(width: 10),
                  Column( //닉네임, 온도
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [//닉네임
                      Text(widget.userName,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row( //온도
                        children: [
                          const Icon(Icons.thermostat,
                              color: Color(0xFF00E676), size: 12),
                          Text(widget.userScore,
                              style: const TextStyle(
                                  color: Color(0xFF00E676), fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(widget.userBadge,
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(), //공백
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.location_on_outlined, color: subTextColor, size: 14, ),
                        label: Text(widget.extraInfoText, style: TextStyle(color: subTextColor, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          alignment: Alignment.centerRight,
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      )
                    ],
                  ),
                ],
              ),

              // 4. 멤버 진행바
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.maxMembers > 0
                            ? (widget.currentMembers / widget.maxMembers)
                                .clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: widget.isDarkMode
                            ? Colors.white12
                            : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isClosed ? Colors.grey : widget.accentColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.currentMembers}/${widget.maxMembers}명',
                    style: TextStyle(
                        color: widget.isClosed ? subTextColor : widget.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // 5. 상세정보 (애니메이션 펼치기)
              SizeTransition(
                sizeFactor: _animation,
                axisAlignment: -1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Divider(
                        color: widget.isDarkMode
                            ? Colors.white12
                            : Colors.black12),
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
                              style: TextStyle(color: textColor, fontSize: 13)),
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
                    if (isAuthor)
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
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: widget.isClosed
                              ? Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode
                                        ? Colors.white12
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text('모집이 마감되었어요',
                                        style: TextStyle(
                                            color: subTextColor,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    final currentUser = Supabase
                                        .instance.client.auth.currentUser;
                                    if (currentUser == null) return;
                                    try {
                                      final existing =
                                          await Supabase.instance.client
                                              .from('chat_rooms')
                                              .select()
                                              .eq('gathering_id',
                                                  widget.gatheringId)
                                              .eq('guest_id', currentUser.id)
                                              .maybeSingle();

                                      String roomId;
                                      if (existing != null) {
                                        roomId = existing['id'];
                                      } else {
                                        final created = await Supabase
                                            .instance.client
                                            .from('chat_rooms')
                                            .insert({
                                              'gathering_id':
                                                  widget.gatheringId,
                                              'gathering_title':
                                                  widget.gatheringTitle,
                                              'host_id': widget.authorId,
                                              'host_nickname':
                                                  widget.hostNickname,
                                              'guest_id': currentUser.id,
                                              'guest_nickname': currentUser
                                                      .userMetadata?[
                                                          'display_name'] ??
                                                  currentUser.email ??
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
                                          builder: (context) => ChatRoomScreen(
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
                                  label: const Text('채팅하기',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E676),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),

              // 6. 펼치기/접기 버튼
              Center(
                child: IconButton(
                  onPressed: _toggleExpand,
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: subTextColor,
                  ),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  List<Map<String, dynamic>> _gatherings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGatherings();
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
    final isPostalCode = RegExp(r'^\d{5}$').hasMatch(location);
    if (location.isEmpty || isPostalCode) {
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
                        Text('새로운 크루 모집하기', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('함께 땀 흘릴 메이트를 찾아보세요', style: TextStyle(color: subTextColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
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
                      color: const Color(0xFF00E676).withValues(alpha: 0.7)
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // 실시간 모집바
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('실시간 모집 ✨', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                
                PopupMenuButton<String>(
                  color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  position: PopupMenuPosition.under,
                  
                  onSelected: (String newValue) {
                    setState(() {
                      _currentSort = newValue;
                    });
                    _loadGatherings();
                  },
                  
                  itemBuilder: (BuildContext context) {
                    return ['최신순', '오래된순', '인기순', 'A-Z 순'].map((String choice) {
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
                    }).toList();
                  },
                  
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

            // 모집 리스트 카드 (Supabase 연동)
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
            else if (_gatherings.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    '아직 모집글이 없어요.\n첫 번째로 크루를 모집해보세요! 🏃',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 15, height: 1.6),
                  ),
                ),
              )
            else
              ..._gatherings.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: RecruitmentCard(
                  isDarkMode: isDarkMode,
                  accentColor: _categoryColor(g['category'] ?? '기타'),
                  category: g['category'] ?? '기타',
                  timeAgo: _formatTimeAgo(g['created_at'] ?? DateTime.now().toIso8601String()),
                  statusText: '👥 ${g['current_members']}/${g['max_members']}',
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
                ),
              )),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// 모집글 추가 사항 애니메이션 영역 기능 (저장 데이터 협의 필요)
class RecruitmentCard extends StatefulWidget {
  final bool isDarkMode;
  final Color accentColor;
  final String category;
  final String timeAgo;
  final String statusText;
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

  const RecruitmentCard({
    super.key,
    required this.isDarkMode,
    required this.accentColor,
    required this.category,
    required this.timeAgo,
    required this.statusText,
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
  });

  @override
  State<RecruitmentCard> createState() => _RecruitmentCardState();
}

class _RecruitmentCardState extends State<RecruitmentCard> with SingleTickerProviderStateMixin {
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
        _expandController.forward(); // 열기 애니메이션 재생
      } else {
        _expandController.reverse(); // 닫기 애니메이션 재생
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subTextColor = widget.isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: widget.accentColor, width: 6)),
          ),
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 5), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 카테고리 및 시간
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(widget.category, style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Text(widget.timeAgo, style: TextStyle(color: subTextColor, fontSize: 12)),
                  const Spacer(),
                  Text(widget.statusText, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  // 작성자 본인에게만 수정/삭제 메뉴 표시
                  if (Supabase.instance.client.auth.currentUser?.id == widget.authorId)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subTextColor, size: 18),
                      color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit?.call();
                        if (value == 'delete') widget.onDelete?.call();
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: widget.isDarkMode ? Colors.white70 : Colors.black87),
                              const SizedBox(width: 8),
                              const Text('수정'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('삭제', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 2. 제목
              Text(widget.title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // 3. 유저 정보 및 위치
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[300],
                    child: Icon(Icons.person, color: subTextColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.userName, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.thermostat, color: Color(0xFF00E676), size: 12),
                          Text(widget.userScore, style: TextStyle(color: const Color(0xFF00E676), fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(widget.userBadge, style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: Icon(widget.extraInfoIcon, color: textColor),
                    label: Text(widget.extraInfoText, style: TextStyle(color: textColor)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                  )
                ],
              ),
              
              // 💡 4. 상세정보 영역 (정보 및 애니메이션 적용)
              SizeTransition(
                sizeFactor: _animation,
                axisAlignment: -1.0, // 위치 고정
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Divider(color: widget.isDarkMode ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 12),
                    
                    // 모집 날짜 정보
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: subTextColor, size: 16),
                        const SizedBox(width: 8),
                        Text('모집 기간: ', style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(widget.gatherDate, style: TextStyle(color: textColor, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 본문 내용
                    Text(
                      widget.description,
                      style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                                      // 채팅하기 버튼 (비작성자에게만 표시)
                                      if (Supabase.instance.client.auth.currentUser?.id != widget.authorId)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                final currentUser = Supabase.instance.client.auth.currentUser;
                                                if (currentUser == null) return;
                                                try {
                                                  // 기존 채팅방 조회
                                                  final existing = await Supabase.instance.client
                                                      .from('chat_rooms')
                                                      .select()
                                                      .eq('gathering_id', widget.gatheringId)
                                                      .eq('guest_id', currentUser.id)
                                                      .maybeSingle();

                                                  String roomId;
                                                  if (existing != null) {
                                                    roomId = existing['id'];
                                                  } else {
                                                    final created = await Supabase.instance.client
                                                        .from('chat_rooms')
                                                        .insert({
                                                          'gathering_id': widget.gatheringId,
                                                          'gathering_title': widget.gatheringTitle,
                                                          'host_id': widget.authorId,
                                                          'host_nickname': widget.hostNickname,
                                                          'guest_id': currentUser.id,
                                                          'guest_nickname': currentUser.userMetadata?['display_name'] ?? currentUser.email ?? '익명',
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
                                                        otherUserNickname: widget.hostNickname,
                                                        gatheringTitle: widget.gatheringTitle,
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('채팅 시작 실패: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.black),
                                              label: const Text('채팅하기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00E676),
                                                elevation: 0,
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

              // 💡 5. 펼치기/접기 화살표 버튼
              Center(
                child: IconButton(
                  onPressed: _toggleExpand,
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                    color: subTextColor
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
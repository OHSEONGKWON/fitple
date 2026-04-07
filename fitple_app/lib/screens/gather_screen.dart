import 'package:flutter/material.dart';
import 'gather_edit_screen.dart';

class GatherScreen extends StatefulWidget {
  const GatherScreen({super.key});

  @override
  State<GatherScreen> createState() => _GatherScreenState();
}

class _GatherScreenState extends State<GatherScreen> {
  String _currentSort = '최신순';

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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GatherEditScreen(),
                            fullscreenDialog: true,
                          ),
                        );
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

            // 모집 리스트 카드 (프론트 테스트용 임시 데이터)

            RecruitmentCard(
              isDarkMode: isDarkMode,
              accentColor: Colors.redAccent,
              category: '러닝크루',
              timeAgo: '10', 
              statusText: '👥 2/4',
              title: '오늘 저녁 남강 나이트 러닝!',
              description: '평거동 야외무대에서 5km 정도 가볍게 뛸 초보자 분들 구합니다. 부담 없이 오셔서 같이 땀 흘려요!',
              gatherDate: '2026.04.10 ~ 2026.04.15', // 임시 모집 날짜 추가
              userName: '달리는호랑이',
              userScore: '98점',
              userBadge: '러닝 3년차',
              extraInfoIcon: Icons.location_on_outlined,
              extraInfoText: '평거동',
            ),
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
  final String gatherDate; // 모집 날짜
  final String userName;
  final String userScore;
  final String userBadge;
  final IconData extraInfoIcon;
  final String extraInfoText;

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
                  Text('${widget.timeAgo}분 전', style: TextStyle(color: subTextColor, fontSize: 12)),
                  const Spacer(),
                  Text(widget.statusText, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
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
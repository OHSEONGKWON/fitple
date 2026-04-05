import 'package:flutter/material.dart';

// 💡 1. 정렬 글씨가 바뀌어야 하므로 StatefulWidget으로 변경!
class GatherScreen extends StatefulWidget {
  const GatherScreen({super.key});

  @override
  State<GatherScreen> createState() => _GatherScreenState();
}

class _GatherScreenState extends State<GatherScreen> {
  // 💡 2. 현재 선택된 정렬 방식을 기억하는 변수
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
            // ==========================================
            // 1. 새로운 크루 모집하기 배너
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // 네온 그린 아이콘 박스
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
                  // 글씨 영역
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
                  // 💡 질문자님이 직접 수정하신 오른쪽 + 버튼 (완벽합니다!)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {}, 
                      icon: const Icon(Icons.add_circle_outlined),
                      iconSize: 35, 
                      color: const Color(0xFF00E676).withValues(alpha: 0.7)
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // ==========================================
            // 2. 실시간 모집 헤더 (🔥 끊어졌던 정렬 드롭다운 기능 복구!)
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('실시간 모집 ✨', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                
                // 정렬 드롭다운 메뉴 버튼
                PopupMenuButton<String>(
                  color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  position: PopupMenuPosition.under, 
                  
                  onSelected: (String newValue) {
                    setState(() {
                      _currentSort = newValue; // 선택한 항목으로 화면 갱신
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
            ), // 👈 여기서 Row가 완벽하게 닫힙니다!
            const SizedBox(height: 15),

            // ==========================================
            // 3. 모집 리스트 카드
            // ==========================================
            _buildRecruitmentCard(
              isDarkMode: isDarkMode,
              accentColor: Colors.redAccent,
              category: '러닝크루',
              timeAgo: '10분 전',
              statusText: '👥 2/4',
              statusColor: Colors.white,
              title: '오늘 저녁 남강 나이트 러닝!',
              description: '평거동 야외무대에서 5km 정도 가볍게 뛸 초...',
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

  // 💡 [함수] 카드 디자인 공장
  Widget _buildRecruitmentCard({
    required bool isDarkMode,
    required Color accentColor,
    required String category,
    required String timeAgo,
    required String statusText,
    required Color statusColor,
    required String title,
    required String description,
    required String userName,
    required String userScore,
    required String userBadge,
    required IconData extraInfoIcon,
    required String extraInfoText,
  }) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 6)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(category, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Text(timeAgo, style: TextStyle(color: subTextColor, fontSize: 12)),
                  const Spacer(),
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(color: subTextColor, fontSize: 14),
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[300],
                    child: Icon(Icons.person, color: subTextColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.thermostat, color: Color(0xFF00E676), size: 12),
                          Text(userScore, style: TextStyle(color: const Color(0xFF00E676), fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(userBadge, style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(extraInfoIcon, color: subTextColor, size: 14),
                  const SizedBox(width: 4),
                  Text(extraInfoText, style: TextStyle(color: subTextColor, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
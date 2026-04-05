import 'package:flutter/material.dart';
import 'gather_edit_screen.dart';

class GatherScreen extends StatefulWidget {
  const GatherScreen({super.key});

  @override
  State<GatherScreen> createState() => _GatherScreenState();
}

class _GatherScreenState extends State<GatherScreen> {
  // 현재 선택된 정렬 방식을 기억하는 변수
  String _currentSort = '최신순';

  @override
  Widget build(BuildContext context) { //그냥 기본 설정을 저장하는 부분
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column( //페이지 전체의 틀을 column으로 잡음
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. 새로운 크루 모집하기 배너
            // ==========================================
            Container(//새로운 크루 모집하기 상자 위젯
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor, //미리 저장해둔 색
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // 네온 그린 '아이콘(사람 두명 아이콘)' 박스
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
                      children: [ //모집 글귀
                        Text('새로운 크루 모집하기', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('함께 땀 흘릴 메이트를 찾아보세요', style: TextStyle(color: subTextColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container( //!! 중요 !! 모집글 버튼
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton( //버튼 생성
                      onPressed: () {
                      //버튼을 누르면 새 창이 아래에서 위로 올라오도록 설정
                        Navigator.push(
                          context,
                        MaterialPageRoute(
                          builder: (context) => const GatherEditScreen(),
                          fullscreenDialog: true, //아래에서 위로 올라오는 모달 창 느낌연출
                          ),
                        );
                      },  
                      icon: const Icon(Icons.add_circle_outlined), //버튼 아이콘 생김새 설정
                      iconSize: 35, 
                      color: const Color(0xFF00E676).withValues(alpha: 0.7)
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // ==========================================
            // 2. 실시간 모집 헤더 
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,//양 끝으로 정렬
              children: [
                Text('실시간 모집 ✨', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                
                // 정렬 드롭다운 메뉴 버튼
                PopupMenuButton<String>(
                  color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  position: PopupMenuPosition.under, //밑으로 내려오도록 설정
                  
                  onSelected: (String newValue) {
                    setState(() {
                      _currentSort = newValue; // 선택한 항목으로 화면 갱신
                    });
                  },
                  
                  itemBuilder: (BuildContext context) { //박스를 여러개 만듦
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
                  
                  child: Container( //기본 박스 생성
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(_currentSort, style: TextStyle(color: subTextColor, fontSize: 13)), //저장된 문자열 출력
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: subTextColor, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // ==========================================
            // 3. 모집 리스트 카드
            // ==========================================
            _buildRecruitmentCard(
              isDarkMode: isDarkMode,
              accentColor: Colors.redAccent,
              category: '러닝크루',
              timeAgo: '10', //수정사항 : 문자열에서 f스트링으로
              statusText: '👥 2/4',
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
  Widget _buildRecruitmentCard({ //여기부터 바로 위에 저장된 문자열(변수) 선언과 이 변수들을 이용한 모집글 디자인..
    required bool isDarkMode, //다크모드 인가요?
    required Color accentColor, //왼쪽 줄 색깔
    required String category, //어느 종목인지
    required String timeAgo, //몇분전인지
    required String statusText, //현재원/총인원
    required String title, //글제목
    required String description, //글 성명(내용)
    required String userName, //유저닉네임
    required String userScore, //유저점수
    required String userBadge, //유저 특징, 상태 표시
    required IconData extraInfoIcon, //위치 아이콘
    required String extraInfoText, //장소 지명
  }) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white; //상태에 따른 배경색
    final textColor = isDarkMode ? Colors.white : Colors.black; //상태에 따른 텍스트 색
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    //
    //추후에 수정해야할 사항 다수 존재(컨테이너 클릭 여부, 위치아이콘 클릭, 프로필 아이콘->사진화)
    //
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
                  Container( //종목을 담는 상자(왼쪽 줄이랑 같은 색으로 채워짐) : 예시의 경우 러닝크루
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(category, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ), //여기까지
                  const SizedBox(width: 10),
                  Text('$timeAgo분 전', style: TextStyle(color: subTextColor, fontSize: 12)), //몇분전인지 f스트링으로 문자열만 받기(나중엔 int형으로 받기)
                  const Spacer(),
                  Text(statusText, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)), //얘도 나중에 수정하기(문자열 > 현재모집인수/최대모집인수)
                ],//여기까지 젤 윗줄
              ),
              const SizedBox(height: 16), 
              Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)), //제목(굵게!!)
              const SizedBox(height: 6),
              Text(
                description, //설명글란
                style: TextStyle(color: subTextColor, fontSize: 14),
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row( //젤 밑부분 시작
                children: [
                  CircleAvatar( //프로필을 나타냄
                    radius: 16,
                    backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[300],
                    child: Icon(Icons.person, color: subTextColor, size: 20), //아이콘에서 나중엔 클릭가능한 이미지로
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)), //유저이름
                      const SizedBox(height: 2),
                      Row(
                        children: [ //유저점수, 특징을 담는 Row
                          const Icon(Icons.thermostat, color: Color(0xFF00E676), size: 12),
                          Text(userScore, style: TextStyle(color: const Color(0xFF00E676), fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(userBadge, style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.location_on_outlined, color: textColor),
                  label: Text(extraInfoText, style: TextStyle(color: textColor)),
                  style: ElevatedButton.styleFrom( //버튼 스타일
                    backgroundColor: cardColor,
                    elevation: 0,           // 1. 기본 그림자 제거
                    shadowColor: Colors.transparent, // 2. 그림자 색상을 투명하게 (확실하게 제거)
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 버튼 안쪽 여백
                  ).copyWith(
                    // 3. 클릭 시 물결 효과(Splash)와 마우스 오버 효과 모두 제거
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    // 4. 그림자가 퍼지는 효과(SurfaceTintColor)도 투명하게
                    surfaceTintColor: WidgetStateProperty.all(Colors.transparent), //나중에 싹다 이런식으로 바꿔야 할듯(완전히 상호작용 표시 없는 버튼 완성)
                  ),
                )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
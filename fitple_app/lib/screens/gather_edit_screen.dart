import 'package:flutter/material.dart';
// 나중에 백엔드(Supabase 등) 연결 시 사용할 패키지를 대비해 둡니다.
// import 'package:supabase_flutter/supabase_flutter.dart'; 

class GatherEditScreen extends StatefulWidget {
  const GatherEditScreen({super.key});

  @override
  State<GatherEditScreen> createState() => _GatherEditScreenState();
}

class _GatherEditScreenState extends State<GatherEditScreen> {
  // 1. 입력 필드 컨트롤러
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  
  // 2. 선택 상태 변수들
  String _selectedCategory = '축구'; // 기본 선택 종목
  DateTimeRange? _selectedDateRange; // 모집 날짜 범위

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 💡 달력을 띄워서 날짜 범위를 선택하게 해주는 함수
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(), // 오늘부터
      lastDate: DateTime.now().add(const Duration(days: 365)), // 1년 뒤까지만 선택 가능
      builder: (context, child) {
        // 달력 테마를 앱의 브랜드 컬러에 맞게 살짝 수정
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF00E676), // 헤더 배경색 (네온그린)
              onPrimary: Colors.black, // 헤더 글씨색
              onSurface: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // 💡 작성 완료(저장) 함수
  Future<void> _submitGather() async {
    // 1. 유효성 검사 (제목이나 내용이 비어있는지 확인)
    if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 본문을 모두 입력해주세요!')),
      );
      return;
    }

    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모집 날짜를 선택해주세요!')),
      );
      return;
    }

    // =========================================================
    // 백엔드(Supabase) DB 저장 로직
    // =========================================================

    // 2. 테스트용: 저장이 완료되었다고 가정하고 이전 화면으로 돌아가기
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('새로운 모집글이 등록되었습니다! 🎉')),
    );
    Navigator.pop(context, true); // true를 넘겨서 성공적으로 글이 써졌음을 이전 화면에 알림
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDarkMode ? Colors.white70 : Colors.black87,
    );

    return Scaffold( //여기부터 디자인
      appBar: AppBar(
        title: const Text('새 크루 모집하기', style: TextStyle(
          fontWeight: FontWeight(700),
          )), //
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // 작성 취소 느낌을 주기 위해 X 버튼 사용
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              // ==============================
              // 1. 모집 종목 (카테고리)
              // ==============================
              Text('모집 종목', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8, // 줄 바꿈 시 위아래 간격
                children: ['축구', '족구', '배구', '배드민턴', '헬스', '러닝', '기타'].map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    selectedColor: const Color(0xFF00E676).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF00E676) 
                          : (isDarkMode ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                      ),
                    ),
                    backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ==============================
              // 2. 제목
              // ==============================
              Text('제목', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: '예: 평거동 야외무대에서 가볍게 뛰실 분!',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white30 : Colors.black26, 
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ==============================
              // 3. 본문 내용
              // ==============================
              Text('상세 내용', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 5, // 본문이라 창을 크게 열어둠
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: '모임 장소, 실력, 준비물 등 상세한 내용을 적어주세요.',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white30 : Colors.black26, 
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ==============================
              // 4. 모집 날짜 (범위 선택)
              // ==============================
              Text('모집 기간', style: labelStyle),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDateRange, // 누르면 달력 팝업 실행
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: isDarkMode ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDateRange == null
                            ? '시작일과 종료일을 선택해주세요'
                            : '${_selectedDateRange!.start.month}월 ${_selectedDateRange!.start.day}일 ~ ${_selectedDateRange!.end.month}월 ${_selectedDateRange!.end.day}일',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDateRange == null 
                              ? (isDarkMode ? Colors.white30 : Colors.black38) 
                              : (isDarkMode ? Colors.white : Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ==============================
              // 5. 모집 인원 (최소 ~ 최대)
              // ==============================
              Text('모집 인원 (본인 제외)', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 최소 인원 입력칸
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '최소',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black26),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  
                  // 가운데 물결 표시
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('~', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  
                  // 최대 인원 입력칸
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '최대',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black26),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  
                  // 끝에 '명' 텍스트
                  const SizedBox(width: 12),
                  Text('명', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 40),

              // ==============================
              // 6. 저장 & 취소 버튼
              // ==============================
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitGather,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '모집글 등록하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.black26,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }
}
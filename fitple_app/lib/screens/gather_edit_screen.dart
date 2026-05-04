import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker_screen.dart';

class GatherEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const GatherEditScreen({super.key, this.initialData});

  @override
  State<GatherEditScreen> createState() => _GatherEditScreenState();
}

class _GatherEditScreenState extends State<GatherEditScreen> {
  // 1. 입력 필드 컨트롤러
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _minMembersController;
  late TextEditingController _maxMembersController;

  // 2. 선택 상태 변수들
  String _selectedCategory = '축구'; // 기본 선택 종목
  DateTimeRange? _selectedDateRange; // 모집 날짜 범위
  LatLng? _pickedLatLng; // 지도에서 선택한 좌표

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _titleController = TextEditingController(text: d?['title'] ?? '');
    _descriptionController = TextEditingController(text: d?['description'] ?? '');
    _locationController = TextEditingController(text: d?['location'] ?? '');
    _minMembersController = TextEditingController(text: d?['min_members']?.toString() ?? '');
    _maxMembersController = TextEditingController(text: d?['max_members']?.toString() ?? '');
    _selectedCategory = d?['category'] ?? '축구';
    if (d != null && d['gather_start'] != null && d['gather_end'] != null) {
      _selectedDateRange = DateTimeRange(
        start: DateTime.parse(d['gather_start']),
        end: DateTime.parse(d['gather_end']),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _minMembersController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLatLng: _pickedLatLng),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedLatLng = result['latLng'] as LatLng?;
        final address = result['address'] as String? ?? '';
        if (address.isNotEmpty) {
          _locationController.text = address;
        }
      });
    }
  }


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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final minMembers = int.tryParse(_minMembersController.text.trim()) ?? 1;
    final maxMembers = int.tryParse(_maxMembersController.text.trim());
    final location = _locationController.text.trim();
    if (maxMembers == null || maxMembers < minMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모집 인원을 올바르게 입력해주세요.')),
      );
      return;
    }

    if (RegExp(r'^\d{5}$').hasMatch(location)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('우편번호 대신 동네/장소명을 입력해주세요.')),
      );
      return;
    }

    final isEdit = widget.initialData != null;
    try {
      if (isEdit) {
        await Supabase.instance.client
            .from('gatherings')
            .update({
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'category': _selectedCategory,
              'location': location,
              'gather_start': _selectedDateRange!.start.toIso8601String().split('T')[0],
              'gather_end': _selectedDateRange!.end.toIso8601String().split('T')[0],
              'min_members': minMembers,
              'max_members': maxMembers,
            })
            .eq('id', widget.initialData!['id']);
      } else {
        await Supabase.instance.client.from('gatherings').insert({
          'user_id': user.id,
          'user_nickname': user.userMetadata?['display_name'] ?? user.email ?? '익명',
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'location': location,
          'gather_start': _selectedDateRange!.start.toIso8601String().split('T')[0],
          'gather_end': _selectedDateRange!.end.toIso8601String().split('T')[0],
          'min_members': minMembers,
          'max_members': maxMembers,
          'current_members': 1,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? '모집글이 수정되었습니다! ✏️' : '새로운 모집글이 등록되었습니다! 🎉')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? '수정 실패: $e' : '등록 실패: $e')),
      );
    }
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
        title: Text(
          widget.initialData != null ? '모집글 수정하기' : '새 크루 모집하기',
          style: const TextStyle(fontWeight: FontWeight(700)),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // 통일성을 위해 뒤로가기로 하였으나, x표시로 할지 의논을 요함
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
                    selectedColor: const Color(0xFF00E676).withValues(alpha: 0.2),
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
                      controller: _minMembersController,
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
                      controller: _maxMembersController,
                    ),
                  ),
                  
                  // 끝에 '명' 텍스트
                  const SizedBox(width: 12),
                  Text('명', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),

              // ==============================
              // 6. 장소
              // ==============================
              Text('장소', style: labelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: '예: 평거동 야외무대',
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
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openMapPicker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('지도 선택'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ==============================
              // 7. 저장 & 취소 버튼
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
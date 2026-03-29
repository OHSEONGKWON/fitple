import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late String _selectedGender;
  late int _selectedAge;
  late List<String> _interests;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _nicknameController = TextEditingController(
      text: user?.userMetadata?['display_name'] ?? '',
    );
    _bioController = TextEditingController(
      text: user?.userMetadata?['bio'] ?? '',
    );
    _selectedGender = user?.userMetadata?['gender'] ?? '미선택';
    _selectedAge = int.tryParse(user?.userMetadata?['age'] ?? '25') ?? 25;
    _interests =
        (user?.userMetadata?['interests'] as String?)?.split(',') ?? [];
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'display_name': _nicknameController.text,
            'bio': _bioController.text,
            'gender': _selectedGender,
            'age': _selectedAge.toString(),
            'interests': _interests.join(','),
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 저장되었습니다.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 닉네임 입력
              Text(
                '닉네임',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: '닉네임을 입력하세요',
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 소개글 입력
              Text(
                '소개글',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '자신을 소개하는 글을 작성하세요',
                  filled: true,
                  fillColor: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 성별 선택
              Text(
                '성별',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '남성', label: Text('남성')),
                  ButtonSegment(value: '여성', label: Text('여성')),
                  ButtonSegment(value: '미선택', label: Text('미선택')),
                ],
                selected: {_selectedGender},
                onSelectionChanged: (value) =>
                    setState(() => _selectedGender = value.first),
              ),
              const SizedBox(height: 16),

              // 나이 선택
              Text(
                '나이: $_selectedAge세',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              Slider(
                value: _selectedAge.toDouble(),
                min: 18,
                max: 70,
                divisions: 52,
                label: '$_selectedAge',
                onChanged: (value) =>
                    setState(() => _selectedAge = value.toInt()),
              ),
              const SizedBox(height: 16),

              // 관심사 선택
              Text(
                '관심사',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['헬스', '요가', '러닝', '수영', '등산', '복싱'].map((interest) {
                  final isSelected = _interests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _interests.add(interest);
                        } else {
                          _interests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // 저장 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 취소 버튼
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
            ],
          ),
        ),
      ),
    );
  }
}

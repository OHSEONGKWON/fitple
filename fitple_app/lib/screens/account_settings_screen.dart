import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isPrivate = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_settings')
          .select('is_private')
          .eq('user_id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isPrivate = data?['is_private'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() { _isPrivate = value; _isSaving = true; });
    try {
      // 기존 행이 있으면 update, 없으면 insert
      final existing = await Supabase.instance.client
          .from('user_settings')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (existing != null) {
        await Supabase.instance.client
            .from('user_settings')
            .update({
              'is_private': value,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('user_settings').insert({
          'user_id': user.id,
          'is_private': value,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '비공개 계정으로 변경되었습니다' : '공개 계정으로 변경되었습니다'),
            backgroundColor: const Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // 값 유지, 에러 메시지만 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장 실패: Supabase에서 supabase_feed.sql을 먼저 실행해주세요'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('계정 설정',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // 섹션 레이블
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text('공개 범위',
                      style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),

                // 비공개 계정 토글
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDarkMode)
                        BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isPrivate
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            color: const Color(0xFF00E676),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('비공개 계정',
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                _isPrivate
                                    ? '팔로워만 내 게시물을 볼 수 있어요'
                                    : '누구나 내 게시물을 볼 수 있어요',
                                style: TextStyle(
                                    color: subTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E676)))
                            : Switch(
                                value: _isPrivate,
                                onChanged: _togglePrivacy,
                                activeThumbColor: const Color(0xFF00E676),
                                activeTrackColor: const Color(0xFF00E676)
                                    .withValues(alpha: 0.4),
                              ),
                      ],
                    ),
                  ),
                ),

                // 설명 텍스트
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    _isPrivate
                        ? '비공개 상태에서는 새 팔로우 요청을 직접 수락하거나 거절할 수 있습니다.'
                        : '공개 상태에서는 누구든지 팔로우하고 게시물을 볼 수 있습니다.',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

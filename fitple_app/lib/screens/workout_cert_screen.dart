import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class WorkoutCertScreen extends StatefulWidget {
  const WorkoutCertScreen({super.key});

  @override
  State<WorkoutCertScreen> createState() => _WorkoutCertScreenState();
}

class _WorkoutCertScreenState extends State<WorkoutCertScreen> {
  bool _isLoading = true;
  bool _isCertifiedToday = false;
  int _streakCount = 0;
  int _totalPoints = 0;
  int _totalCertifications = 0;
  bool _isSubmitting = false;
  Set<String> _certDates = {};

  static String get _todayStr {
    final now = DateTime.now().toLocal();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('workout_certifications')
            .select('id')
            .eq('user_id', user.id)
            .eq('cert_date', _todayStr)
            .maybeSingle(),
        Supabase.instance.client
            .from('user_points')
            .select()
            .eq('user_id', user.id)
            .maybeSingle(),
      ]);
      final datesRaw = await Supabase.instance.client
          .from('workout_certifications')
          .select('cert_date')
          .eq('user_id', user.id)
          .order('cert_date', ascending: false)
          .limit(60);
      if (mounted) {
        final points = results[1];
        setState(() {
          _isCertifiedToday = results[0] != null;
          _streakCount = (points?['streak_count'] as int?) ?? 0;
          _totalPoints = (points?['total_points'] as int?) ?? 0;
          _totalCertifications = (points?['total_certifications'] as int?) ?? 0;
          _certDates =
              (datesRaw).map((r) => r['cert_date'] as String).toSet();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calcPoints(int streak) {
    int p = 10;
    if (streak > 0 && streak % 7 == 0) p += 30;
    if (streak > 0 && streak % 30 == 0) p += 100;
    return p;
  }

  Future<void> _certify(ImageSource source) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final bytes = await picked.readAsBytes();
      final fileName = 'workouts/${user.id}/$_todayStr.jpg';

      await Supabase.instance.client.storage
          .from('workout-certs')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(upsert: true));

      final nickname = user.userMetadata?['display_name'] as String? ??
          user.email?.split('@').first ??
          '사용자';
      await Supabase.instance.client.from('workout_certifications').insert({
        'user_id': user.id,
        'image_url': fileName,
        'cert_date': _todayStr,
        'user_nickname': nickname,
      });

      final pointsRecord = await Supabase.instance.client
          .from('user_points')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final lastDate = pointsRecord?['last_certified_date'] as String?;
      int newStreak;
      if (lastDate != null) {
        final last = DateTime.parse(lastDate).toLocal();
        final yesterday =
            DateTime.now().toLocal().subtract(const Duration(days: 1));
        newStreak = (last.year == yesterday.year &&
                last.month == yesterday.month &&
                last.day == yesterday.day)
            ? ((pointsRecord?['streak_count'] as int?) ?? 0) + 1
            : 1;
      } else {
        newStreak = 1;
      }

      final earned = _calcPoints(newStreak);
      final currentPts = (pointsRecord?['total_points'] as int?) ?? 0;
      final currentCerts = (pointsRecord?['total_certifications'] as int?) ?? 0;

      if (pointsRecord == null) {
        await Supabase.instance.client.from('user_points').insert({
          'user_id': user.id,
          'total_points': earned,
          'streak_count': newStreak,
          'total_certifications': 1,
          'last_certified_date': _todayStr,
        });
      } else {
        await Supabase.instance.client.from('user_points').update({
          'total_points': currentPts + earned,
          'streak_count': newStreak,
          'total_certifications': currentCerts + 1,
          'last_certified_date': _todayStr,
        }).eq('user_id', user.id);
      }

      if (mounted) {
        setState(() {
          _isCertifiedToday = true;
          _streakCount = newStreak;
          _totalPoints = currentPts + earned;
          _totalCertifications = currentCerts + 1;
          _certDates = {..._certDates, _todayStr};
          _isSubmitting = false;
        });
        _showSuccess(earned, newStreak,
            onConfirm: () => _showStoryShareDialog(bytes));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recertify(ImageSource source) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final bytes = await picked.readAsBytes();
      final fileName = 'workouts/${user.id}/$_todayStr.jpg';

      await Supabase.instance.client.storage
          .from('workout-certs')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(upsert: true));

      await Supabase.instance.client
          .from('workout_certifications')
          .update({'image_url': fileName})
          .eq('user_id', user.id)
          .eq('cert_date', _todayStr);

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 사진이 변경됐습니다! ✅'),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 2),
          ),
        );
        _showStoryShareDialog(bytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRecertifySheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text('인증 사진 변경',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF00E676)),
                title: Text('카메라',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _recertify(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF00E676)),
                title: Text('갤러리',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _recertify(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF00E676)),
                title: Text('카메라',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _certify(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF00E676)),
                title: Text('갤러리',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                  _certify(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(int points, int streak, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text('오운완 인증 완료!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('+$points 포인트 획득!',
                style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('연속 $streak일 운동 중! 🔥',
                style: const TextStyle(fontSize: 13, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            child: const Text('확인',
                style: TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStoryShareDialog(Uint8List bytes) {
    if (!mounted) return;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            const Text('📸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('스토리 공유',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black)),
          ],
        ),
        content: Text(
          '오운완 사진을 내 스토리에 올리겠습니까?\n(24시간 후 자동으로 삭제됩니다)',
          style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _shareToStory(bytes);
            },
            child: const Text('네',
                style: TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToStory(Uint8List bytes) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final fileName =
          'stories/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('stories')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(upsert: false));
      await Supabase.instance.client.from('stories').insert({
        'user_id': user.id,
        'image_url': fileName,
        'user_nickname': user.userMetadata?['display_name'] ??
            user.email?.split('@').first ??
            '사용자',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토리에 공유됐어요! 🎉'),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스토리 업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('오운완 인증',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : RefreshIndicator(
              color: const Color(0xFF00E676),
              onRefresh: _loadStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _StatCard(
                            emoji: '🔥',
                            label: '연속 출석',
                            value: '$_streakCount일',
                            isDarkMode: isDarkMode),
                        const SizedBox(width: 12),
                        _StatCard(
                            emoji: '⭐',
                            label: '총 포인트',
                            value: '$_totalPoints P',
                            isDarkMode: isDarkMode),
                        const SizedBox(width: 12),
                        _StatCard(
                            emoji: '💪',
                            label: '총 운동일',
                            value: '$_totalCertifications일',
                            isDarkMode: isDarkMode),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (_isCertifiedToday)
                      _CertifiedCard(
                        streak: _streakCount,
                        onReCertify:
                            _isSubmitting ? null : _showRecertifySheet,
                      )
                    else
                      _CertifyCard(
                        isDarkMode: isDarkMode,
                        isSubmitting: _isSubmitting,
                        onCertify: _showImageSourceSheet,
                        nextPoints: _calcPoints(_streakCount + 1),
                      ),
                    const SizedBox(height: 28),
                    _AttendanceCalendar(
                      certDates: _certDates,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 28),
                    _PointsGuide(isDarkMode: isDarkMode),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final bool isDarkMode;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _CertifyCard extends StatelessWidget {
  final bool isDarkMode;
  final bool isSubmitting;
  final VoidCallback onCertify;
  final int nextPoints;

  const _CertifyCard({
    required this.isDarkMode,
    required this.isSubmitting,
    required this.onCertify,
    required this.nextPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8FFF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('💪', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            '오늘 운동을 완료했나요?',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            '운동 인증 사진을 올리고\n+$nextPoints 포인트를 받으세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDarkMode ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : onCertify,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.camera_alt_outlined, color: Colors.black),
              label: Text(
                isSubmitting ? '업로드 중...' : '오운완 인증하기',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertifiedCard extends StatelessWidget {
  final int streak;
  final VoidCallback? onReCertify;

  const _CertifiedCard({required this.streak, this.onReCertify});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('오늘 인증 완료!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 8),
          Text(
            '연속 $streak일째 운동 중! 🔥\n내일도 화이팅!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onReCertify,
            icon: const Icon(Icons.photo_camera_outlined,
                size: 15, color: Colors.black54),
            label: const Text('사진 변경',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsGuide extends StatelessWidget {
  final bool isDarkMode;

  const _PointsGuide({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('포인트 적립 안내',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 14),
          _GuideRow('💪', '일일 운동 인증', '+10P', isDarkMode),
          const SizedBox(height: 10),
          _GuideRow('🔥', '7일 연속 출석 보너스', '+30P', isDarkMode),
          const SizedBox(height: 10),
          _GuideRow('🏆', '30일 연속 출석 보너스', '+100P', isDarkMode),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final String emoji;
  final String text;
  final String points;
  final bool isDarkMode;

  const _GuideRow(this.emoji, this.text, this.points, this.isDarkMode);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white60 : Colors.black54))),
        Text(points,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E676))),
      ],
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  final Set<String> certDates;
  final bool isDarkMode;

  const _AttendanceCalendar({
    required this.certDates,
    required this.isDarkMode,
  });

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toLocal();
    // 28일치 (오늘 포함, 4주)
    final days = List.generate(28, (i) => today.subtract(Duration(days: 27 - i)));
    final todayStr = _fmt(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('출석 기록',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black)),
              Text('최근 28일',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white38 : Colors.black38)),
            ],
          ),
          const SizedBox(height: 14),
          // 요일 헤더
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.black38)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 1,
            ),
            itemCount: 28,
            itemBuilder: (_, i) {
              final day = days[i];
              final dateStr = _fmt(day);
              final isCertified = certDates.contains(dateStr);
              final isToday = dateStr == todayStr;

              return Container(
                decoration: BoxDecoration(
                  color: isCertified
                      ? const Color(0xFF00E676)
                      : (isDarkMode ? Colors.white10 : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: const Color(0xFF00E676), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: isCertified
                          ? Colors.black
                          : (isDarkMode ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 6),
              Text('인증 완료',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          isDarkMode ? Colors.white60 : Colors.black54)),
              const SizedBox(width: 16),
              Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 6),
              Text('미인증',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          isDarkMode ? Colors.white60 : Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}

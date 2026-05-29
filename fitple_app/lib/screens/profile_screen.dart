import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'workout_cert_screen.dart';
import 'follow_list_screen.dart';
import 'follow_requests_screen.dart';
import 'account_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _totalPoints = 0;
  int _streakCount = 0;
  int _totalCertifications = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isPrivate = false;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadFollowCounts();
    _loadPrivacySetting();
  }

  void _refreshProfile() {
    setState(() {});
    _loadPoints();
    _loadFollowCounts();
    _loadPrivacySetting();
  }

  Future<void> _loadPrivacySetting() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_settings')
          .select('is_private')
          .eq('user_id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() => _isPrivate = data?['is_private'] as bool? ?? false);
      }
    } catch (_) {}
  }

  Future<void> _loadFollowCounts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final followerList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('following_id', user.id);
      final followingList = await Supabase.instance.client
          .from('follows')
          .select('id')
          .eq('follower_id', user.id);
      final requestList = await Supabase.instance.client
          .from('follow_requests')
          .select('id')
          .eq('target_id', user.id);
      if (mounted) {
        setState(() {
          _followerCount = (followerList as List).length;
          _followingCount = (followingList as List).length;
          _pendingRequestCount = (requestList as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPoints() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_points')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _totalPoints = (data?['total_points'] as int?) ?? 0;
          _streakCount = (data?['streak_count'] as int?) ?? 0;
          _totalCertifications = (data?['total_certifications'] as int?) ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 실패: 다시 시도하세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final nickname =
        user?.userMetadata?['display_name'] as String? ?? '닉네임 없음';
    final email = user?.email ?? '';
    final gender = user?.userMetadata?['gender'] as String? ?? '';
    final age = user?.userMetadata?['age'];
    final bio = user?.userMetadata?['bio'] as String? ?? '';
    final interestsRaw = user?.userMetadata?['interests'] as String? ?? '';
    final interests = interestsRaw.isNotEmpty
        ? interestsRaw.split(',').map((s) => s.trim()).toList()
        : <String>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
                    : [const Color(0xFFF0FFF8), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person,
                          color: Colors.black, size: 48),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileEditScreen()),
                          );
                          if (result == true) _refreshProfile();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 15, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  nickname,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(color: subTextColor, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: user!.id,
                            isFollowers: true,
                          ),
                        ),
                      ).then((_) => _loadFollowCounts()),
                      child: _FollowCountItem(
                          label: '팔로워',
                          count: _followerCount,
                          textColor: textColor,
                          subTextColor: subTextColor),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowListScreen(
                            userId: user!.id,
                            isFollowers: false,
                          ),
                        ),
                      ).then((_) => _loadFollowCounts()),
                      child: _FollowCountItem(
                          label: '팔로잉',
                          count: _followingCount,
                          textColor: textColor,
                          subTextColor: subTextColor),
                    ),
                  ],
                ),
                // 팔로우 요청 배지 (비공개 계정일 때)
                if (_isPrivate && _pendingRequestCount > 0) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FollowRequestsScreen()),
                    ).then((_) => _loadFollowCounts()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF00E676)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_add_outlined,
                              color: Color(0xFF00E676), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '팔로우 요청 $_pendingRequestCount건',
                            style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 기본 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('기본 정보',
                style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.wc_rounded,
                  label: '성별',
                  value: gender.isEmpty ? '미선택' : gender,
                  isDarkMode: isDarkMode,
                  showDivider: true,
                ),
                _InfoTile(
                  icon: Icons.cake_outlined,
                  label: '나이',
                  value: age != null ? '$age세' : '미등록',
                  isDarkMode: isDarkMode,
                  showDivider: false,
                ),
              ],
            ),
          ),

          // 소개글
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('소개글',
                  style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
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
              child: Text(bio,
                  style: TextStyle(
                      color: textColor, fontSize: 14, height: 1.5)),
            ),
          ],

          // 관심사
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('관심 운동',
                  style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests
                    .map((interest) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 운동 기록
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('운동 기록',
                    style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WorkoutCertScreen()),
                  ),
                  child: const Text('출석 캘린더 보기',
                      style: TextStyle(
                          color: Color(0xFF00E676), fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkoutCertScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              child: Row(
                children: [
                  _StatItem(
                      emoji: '🔥',
                      label: '연속 출석',
                      value: '$_streakCount일',
                      textColor: textColor,
                      subColor: subTextColor),
                  _StatItem(
                      emoji: '⭐',
                      label: '총 포인트',
                      value: '$_totalPoints P',
                      textColor: textColor,
                      subColor: subTextColor),
                  _StatItem(
                      emoji: '💪',
                      label: '총 운동일',
                      value: '$_totalCertifications일',
                      textColor: textColor,
                      subColor: subTextColor),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 버튼들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileEditScreen()),
                      );
                      if (result == true) _refreshProfile();
                    },
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: Colors.black),
                    label: const Text('프로필 수정',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AccountSettingsScreen()),
                    ).then((_) => _loadPrivacySetting()),
                    icon: Icon(Icons.settings_outlined,
                        size: 18,
                        color: isDarkMode ? Colors.white60 : Colors.black54),
                    label: Text('계정 설정',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white60 : Colors.black54)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: isDarkMode ? Colors.white24 : Colors.black12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: Icon(Icons.logout_rounded,
                        size: 18,
                        color: isDarkMode ? Colors.white60 : Colors.black54),
                    label: Text('로그아웃',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white60 : Colors.black54)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: isDarkMode ? Colors.white24 : Colors.black12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color textColor;
  final Color subColor;

  const _StatItem({
    required this.emoji,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ),
    );
  }
}

class _FollowCountItem extends StatelessWidget {
  final String label;
  final int count;
  final Color textColor;
  final Color subTextColor;

  const _FollowCountItem({
    required this.label,
    required this.count,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDarkMode;
  final bool showDivider;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDarkMode,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00E676), size: 20),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(color: subTextColor, fontSize: 14)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              thickness: 1,
              color: isDarkMode ? Colors.white10 : Colors.black12,
              indent: 16,
              endIndent: 16),
      ],
    );
  }
}

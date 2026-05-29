import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'workout_cert_screen.dart';
import 'follow_list_screen.dart';
import 'follow_requests_screen.dart';
import 'account_settings_screen.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _totalPoints = 0;
  int _streakCount = 0;
  int _totalCertifications = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isPrivate = false;
  int _pendingRequestCount = 0;

  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPoints();
    _loadFollowCounts();
    _loadPrivacySetting();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {});
    _loadPoints();
    _loadFollowCounts();
    _loadPrivacySetting();
    _loadPosts();
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

  Future<void> _loadPosts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingPosts = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data as List);
          _loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
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
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final headerBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final tabBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final nickname =
        user?.userMetadata?['display_name'] as String? ?? '닉네임 없음';
    final email = user?.email ?? '';
    final gender = user?.userMetadata?['gender'] as String? ?? '';
    final age = user?.userMetadata?['age'];
    final bio = user?.userMetadata?['bio'] as String? ?? '';
    final interestsRaw =
        user?.userMetadata?['interests'] as String? ?? '';
    final interests = interestsRaw.isNotEmpty
        ? interestsRaw.split(',').map((s) => s.trim()).toList()
        : <String>[];

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── 프로필 헤더 ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: headerBg,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  // 아바타 + 수정 버튼
                  Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF00E676).withValues(alpha: 0.3),
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
                  const SizedBox(height: 12),
                  Text(
                    nickname,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 팔로워 / 팔로잉
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FollowListScreen(
                                userId: user!.id, isFollowers: true),
                          ),
                        ).then((_) => _loadFollowCounts()),
                        child: _CountItem(
                            label: '팔로워',
                            count: _followerCount,
                            textColor: textColor,
                            subColor: subColor),
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
                                userId: user!.id, isFollowers: false),
                          ),
                        ).then((_) => _loadFollowCounts()),
                        child: _CountItem(
                            label: '팔로잉',
                            count: _followingCount,
                            textColor: textColor,
                            subColor: subColor),
                      ),
                    ],
                  ),

                  // 팔로우 요청 배지
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
          ),

          // ── 고정 탭바 ──────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF00E676),
                indicatorWeight: 2,
                labelColor: const Color(0xFF00E676),
                unselectedLabelColor: subColor,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on, size: 22)),
                  Tab(icon: Icon(Icons.person_outline, size: 22)),
                ],
              ),
              color: tabBg,
              borderColor: isDarkMode ? Colors.white12 : Colors.black12,
            ),
          ),
        ],

        body: TabBarView(
          controller: _tabController,
          children: [
            // ── 탭 0: 게시물 그리드 ──────────────────────────
            _buildPostsTab(isDarkMode, textColor, subColor),

            // ── 탭 1: 정보 ──────────────────────────────────
            _buildInfoTab(
              isDarkMode: isDarkMode,
              textColor: textColor,
              subColor: subColor,
              cardColor: cardColor,
              email: email,
              gender: gender,
              age: age,
              bio: bio,
              interests: interests,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab(
      bool isDarkMode, Color textColor, Color subColor) {
    if (_loadingPosts) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, size: 56, color: subColor),
            const SizedBox(height: 12),
            Text('아직 게시물이 없어요',
                style: TextStyle(color: subColor, fontSize: 15)),
            const SizedBox(height: 6),
            Text('첫 게시물을 올려보세요!',
                style: TextStyle(color: subColor, fontSize: 13)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final imageUrl = post['image_url'] != null
            ? Supabase.instance.client.storage
                .from('posts')
                .getPublicUrl(post['image_url'] as String)
            : null;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                  post: post, isLiked: false, likeCount: 0),
            ),
          ),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, e, stack) => Container(
                    color: isDarkMode
                        ? const Color(0xFF2C2C2C)
                        : Colors.grey.shade200,
                    child: Icon(Icons.image_outlined,
                        color: subColor, size: 28),
                  ),
                )
              : Container(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    post['content'] as String? ?? '',
                    style: TextStyle(color: subColor, fontSize: 11),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildInfoTab({
    required bool isDarkMode,
    required Color textColor,
    required Color subColor,
    required Color cardColor,
    required String email,
    required String gender,
    required dynamic age,
    required String bio,
    required List<String> interests,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 정보
          Text('기본 정보',
              style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
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
                  icon: Icons.email_outlined,
                  label: '이메일',
                  value: email.isEmpty ? '미등록' : email,
                  isDarkMode: isDarkMode,
                  showDivider: true,
                ),
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
            Text('소개글',
                style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
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

          // 관심 운동
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('관심 운동',
                style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests
                  .map((interest) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF00E676)
                                  .withValues(alpha: 0.3)),
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
          ],

          // 운동 기록
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('운동 기록',
                  style: TextStyle(
                      color: subColor,
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
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                    subColor: subColor),
                _StatItem(
                    emoji: '⭐',
                    label: '총 포인트',
                    value: '$_totalPoints P',
                    textColor: textColor,
                    subColor: subColor),
                _StatItem(
                    emoji: '💪',
                    label: '총 운동일',
                    value: '$_totalCertifications일',
                    textColor: textColor,
                    subColor: subColor),
              ],
            ),
          ),

          // 액션 버튼
          const SizedBox(height: 28),
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
                      color:
                          isDarkMode ? Colors.white60 : Colors.black54)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color:
                        isDarkMode ? Colors.white24 : Colors.black12),
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
                      color:
                          isDarkMode ? Colors.white60 : Colors.black54)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color:
                        isDarkMode ? Colors.white24 : Colors.black12),
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

// ── 고정 탭바 델리게이트 ──────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;
  final Color borderColor;
  static const double _bottomDividerHeight = 1;

  const _StickyTabBarDelegate(this.tabBar,
      {required this.color, required this.borderColor});

  @override
  double get minExtent => tabBar.preferredSize.height + _bottomDividerHeight;
  @override
  double get maxExtent => tabBar.preferredSize.height + _bottomDividerHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          Divider(height: 1, thickness: 1, color: borderColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar ||
      color != oldDelegate.color ||
      borderColor != oldDelegate.borderColor;
}

// ── 공통 위젯 ──────────────────────────────────────────────────
class _CountItem extends StatelessWidget {
  final String label;
  final int count;
  final Color textColor;
  final Color subColor;

  const _CountItem({
    required this.label,
    required this.count,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: subColor)),
      ],
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
          Text(label, style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ),
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
    final subColor = isDarkMode ? Colors.white54 : Colors.black54;
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00E676), size: 20),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(color: subColor, fontSize: 14)),
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

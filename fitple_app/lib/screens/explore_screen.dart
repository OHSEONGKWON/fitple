import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';
import 'gather_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<_UserProfile> _users = [];
  List<_UserProfile> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedSport = '전체';
  final TextEditingController _searchController = TextEditingController();

  static const _sports = ['전체', '러닝', '축구', '족구', '배구', '배드민턴', '헬스', '기타'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final me = Supabase.instance.client.auth.currentUser;
      final data = await Supabase.instance.client
          .from('gatherings')
          .select('user_id, user_nickname, category, created_at')
          .order('created_at', ascending: false);

      final Map<String, _UserProfile> map = {};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final uid = row['user_id'] as String;
        if (uid == me?.id) continue;
        if (!map.containsKey(uid)) {
          map[uid] = _UserProfile(
            userId: uid,
            nickname: row['user_nickname'] as String? ?? '알 수 없음',
            sports: {},
            gatheringCount: 0,
            activeCount: 0,
            lastActiveAt: row['created_at'] as String? ?? '',
          );
        }
        final profile = map[uid]!;
        final cat = row['category'] as String? ?? '기타';
        profile.sports.add(cat);
        profile.gatheringCount++;
        profile.activeCount++;
      }

      final users = map.values.toList()
        ..sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('불러오기 실패: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchSport =
            _selectedSport == '전체' || u.sports.contains(_selectedSport);
        final matchSearch =
            q.isEmpty || u.nickname.toLowerCase().contains(q);
        return matchSport && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgCardColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100];

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      onRefresh: _loadUsers,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 검색바
                  Container(
                    decoration: BoxDecoration(
                      color: bgCardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        _searchQuery = v.trim();
                        _applyFilter();
                      },
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '닉네임으로 검색...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon:
                            Icon(Icons.search, color: subTextColor, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: subTextColor, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _applyFilter();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 스포츠 필터 칩
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _sports.map((sport) {
                        final isSelected = _selectedSport == sport;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedSport = sport);
                            _applyFilter();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00E676)
                                  : bgCardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00E676)
                                    : (isDarkMode
                                        ? Colors.white24
                                        : Colors.black12),
                              ),
                            ),
                            child: Text(
                              sport,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : subTextColor,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        '스포츠 메이트 찾기 🔍',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (!_isLoading)
                        Text(
                          '${_filtered.length}명',
                          style: TextStyle(
                              color: const Color(0xFF00E676),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF00E676)),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _users.isEmpty
                      ? '아직 활동 중인 메이트가 없어요.\n모집글을 먼저 올려보세요! 🏃'
                      : '검색 결과가 없어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: subTextColor, fontSize: 15, height: 1.6),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = _filtered[index];
                    return _UserCard(
                      user: user,
                      isDarkMode: isDarkMode,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final _UserProfile user;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;

  const _UserCard({
    required this.user,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
  });

  Color _sportColor(String sport) {
    switch (sport) {
      case '러닝':
        return Colors.redAccent;
      case '축구':
        return Colors.green;
      case '족구':
        return Colors.orange;
      case '배구':
        return Colors.blue;
      case '배드민턴':
        return Colors.purple;
      case '헬스':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _UserDetailSheet(
                user: user,
                isDarkMode: isDarkMode,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.nickname.isNotEmpty
                          ? user.nickname[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: user.sports.take(4).map((sport) {
                          final color = _sportColor(sport);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              sport,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '모집 ${user.gatheringCount}회',
                      style:
                          TextStyle(color: subTextColor, fontSize: 11),
                    ),
                    if (user.activeCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '활성 ${user.activeCount}',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserDetailSheet extends StatefulWidget {
  final _UserProfile user;
  final bool isDarkMode;

  const _UserDetailSheet({required this.user, required this.isDarkMode});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  List<Map<String, dynamic>> _gatherings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('gatherings')
          .select()
          .eq('user_id', widget.user.userId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _gatherings = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _sportColor(String sport) {
    switch (sport) {
      case '러닝':
        return Colors.redAccent;
      case '축구':
        return Colors.green;
      case '족구':
        return Colors.orange;
      case '배구':
        return Colors.blue;
      case '배드민턴':
        return Colors.purple;
      case '헬스':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _startChat(Map<String, dynamic> gathering) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    try {
      final existing = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('gathering_id', gathering['id'] as String)
          .eq('guest_id', me.id)
          .maybeSingle();

      String roomId;
      if (existing != null) {
        roomId = existing['id'];
      } else {
        final created = await Supabase.instance.client
            .from('chat_rooms')
            .insert({
              'gathering_id': gathering['id'],
              'gathering_title': gathering['title'] ?? '',
              'host_id': widget.user.userId,
              'host_nickname': widget.user.nickname,
              'guest_id': me.id,
              'guest_nickname':
                  me.userMetadata?['display_name'] ?? me.email ?? '익명',
            })
            .select()
            .single();
        roomId = created['id'];
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: roomId,
            otherUserNickname: widget.user.nickname,
            gatheringTitle: gathering['title'] ?? '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채팅 시작 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // 유저 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.nickname.isNotEmpty
                            ? widget.user.nickname[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.user.nickname,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '모집 ${widget.user.gatheringCount}회 · 활성 ${widget.user.activeCount}개',
                          style: TextStyle(
                              color: subTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 스포츠 태그
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.user.sports.map((sport) {
                  final color = _sportColor(sport);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(sport,
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('최근 모집글',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),

            // 모집글 목록
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00E676)))
                  : _gatherings.isEmpty
                      ? Center(
                          child: Text('모집글이 없어요.',
                              style: TextStyle(color: subTextColor)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: _gatherings.length,
                          itemBuilder: (context, index) {
                            final g = _gatherings[index];
                            final isClosed =
                                (g['is_closed'] ?? false) as bool;
                            final accent =
                                _sportColor(g['category'] ?? '기타');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border(
                                    left: BorderSide(
                                        color: isClosed
                                            ? Colors.grey
                                            : accent,
                                        width: 4)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                title: Text(
                                  g['title'] ?? '',
                                  style: TextStyle(
                                    color: isClosed
                                        ? subTextColor
                                        : textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      g['category'] ?? '',
                                      style: TextStyle(
                                          color: accent, fontSize: 12),
                                    ),
                                    if (isClosed) ...[
                                      const SizedBox(width: 8),
                                      const Text('마감',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12)),
                                    ],
                                  ],
                                ),
                                trailing: isClosed
                                    ? null
                                    : TextButton(
                                        onPressed: () =>
                                            _startChat(g),
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00E676)
                                                  .withValues(alpha: 0.15),
                                          foregroundColor:
                                              const Color(0xFF00E676),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                        ),
                                        child: const Text('채팅',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfile {
  final String userId;
  final String nickname;
  final Set<String> sports;
  int gatheringCount;
  int activeCount;
  final String lastActiveAt;

  _UserProfile({
    required this.userId,
    required this.nickname,
    required this.sports,
    required this.gatheringCount,
    required this.activeCount,
    required this.lastActiveAt,
  });
}

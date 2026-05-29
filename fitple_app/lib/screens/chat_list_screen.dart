import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import 'chat_room_screen.dart';
import 'group_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _directRooms = [];
  List<Map<String, dynamic>> _groupRooms = [];
  bool _isLoading = true;
  RealtimeChannel? _messageChannel;
  Set<String> _roomIds = {};
  int _selectedTabIndex = 0; // 0: 개인채팅, 1: 단체채팅

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToNewMessages() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _messageChannel = Supabase.instance.client
        .channel('chat_list_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final msg = payload.newRecord;
            if (msg['sender_id'] == user.id) return;
            if (!_roomIds.contains(msg['room_id'] as String?)) return;
            if (msg['room_id'] == NotificationService.activeChatRoomId) return;

            await NotificationService.showChatNotification(
              title: msg['sender_nickname'] as String? ?? '새 메시지',
              body: msg['message_type'] == 'image'
                  ? '📷 사진을 보냈습니다'
                  : msg['message_type'] == 'schedule_proposal'
                      ? '📅 일정을 제안했습니다'
                      : (msg['content'] as String? ?? ''),
            );

            _loadRooms();
          },
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> _enrichRoom(
      Map<String, dynamic> room, String userId) async {
    final isHost = room['host_id'] == userId;
    final myLastReadAt = (isHost
        ? room['host_last_read_at']
        : room['guest_last_read_at']) as String?;

    final lastMsgsFuture = Supabase.instance.client
        .from('messages')
        .select()
        .eq('room_id', room['id'] as String)
        .order('created_at', ascending: false)
        .limit(1);

    final unreadFuture = myLastReadAt != null
        ? Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('room_id', room['id'] as String)
            .neq('sender_id', userId)
            .gt('created_at', myLastReadAt)
        : Supabase.instance.client
            .from('messages')
            .select('id')
            .eq('room_id', room['id'] as String)
            .neq('sender_id', userId);

    final results = await Future.wait([lastMsgsFuture, unreadFuture]);
    final lastMsgs = results[0] as List;
    final unreads = results[1] as List;

    return {
      ...room,
      '_lastMessage': lastMsgs.isNotEmpty ? lastMsgs.first : null,
      '_unreadCount': unreads.length,
    };
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final hostRooms = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('host_id', user.id);

      final guestRooms = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('guest_id', user.id);

      final all = [
        ...List<Map<String, dynamic>>.from(hostRooms),
        ...List<Map<String, dynamic>>.from(guestRooms),
      ];

      final directEnriched = await Future.wait(
        all.map((room) => _enrichRoom(room, user.id)),
      );

      directEnriched.sort((a, b) {
        final aTime =
            (a['_lastMessage'] as Map?)?['created_at'] as String? ??
                a['created_at'] as String? ??
                '';
        final bTime =
            (b['_lastMessage'] as Map?)?['created_at'] as String? ??
                b['created_at'] as String? ??
                '';
        return bTime.compareTo(aTime);
      });

      final groupRooms = await _loadGroupRooms(user.id);

      _roomIds = directEnriched.map((r) => r['id'] as String).toSet();

      if (mounted) {
        setState(() {
          _directRooms = directEnriched;
          _groupRooms = groupRooms;
          _isLoading = false;
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

  Future<List<Map<String, dynamic>>> _loadGroupRooms(String userId) async {
    final hostRooms = await Supabase.instance.client
        .from('group_chat_rooms')
        .select()
        .eq('host_id', userId);

    final myMessages = await Supabase.instance.client
        .from('group_messages')
        .select('room_id')
        .eq('user_id', userId);

    final roomIds = <String>{
      ...List<Map<String, dynamic>>.from(hostRooms)
          .map((r) => r['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
      ...List<Map<String, dynamic>>.from(myMessages)
          .map((m) => m['room_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };

    if (roomIds.isEmpty) return [];

    final rooms = await Supabase.instance.client
        .from('group_chat_rooms')
        .select()
        .inFilter('id', roomIds.toList());

    final enriched = await Future.wait(
      List<Map<String, dynamic>>.from(rooms).map((room) async {
        final lastMsgs = await Supabase.instance.client
            .from('group_messages')
            .select()
            .eq('room_id', room['id'] as String)
            .order('created_at', ascending: false)
            .limit(1);
        return {
          ...room,
          '_lastMessage': lastMsgs.isNotEmpty ? lastMsgs.first : null,
        };
      }),
    );

    enriched.sort((a, b) {
      final aTime = (a['_lastMessage'] as Map?)?['created_at'] as String? ??
          a['created_at'] as String? ??
          '';
      final bTime = (b['_lastMessage'] as Map?)?['created_at'] as String? ??
          b['created_at'] as String? ??
          '';
      return bTime.compareTo(aTime);
    });

    return enriched;
  }

  String _getOtherNickname(Map<String, dynamic> room) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id == room['host_id']) return room['guest_nickname'] ?? '상대방';
    return room['host_nickname'] ?? '상대방';
  }

  String? _getOtherUserId(Map<String, dynamic> room) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id == room['host_id']) return room['guest_id'] as String?;
    return room['host_id'] as String?;
  }

  String _formatPreviewTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      const days = ['월', '화', '수', '목', '금', '토', '일'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  Future<void> _leaveDirectRoom(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('이 개인 채팅방을 나가시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('chat_rooms')
          .delete()
          .eq('id', roomId);
      _loadRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('나가기 실패: $e')),
      );
    }
  }

  Future<void> _leaveGroupRoom(Map<String, dynamic> room) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final isHost = room['host_id'] == userId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단체채팅 나가기'),
        content: Text(isHost
            ? '호스트가 나가면 단체 채팅방이 삭제됩니다. 계속할까요?'
            : '단체 채팅방에서 나가시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (isHost) {
        await Supabase.instance.client
            .from('group_chat_rooms')
            .delete()
            .eq('id', room['id']);
      } else {
        await Supabase.instance.client
            .from('group_messages')
            .delete()
            .eq('room_id', room['id'])
            .eq('user_id', userId);
      }
      _loadRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('나가기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final rooms = _selectedTabIndex == 0 ? _directRooms : _groupRooms;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        title: Text(
          '채팅',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: subTextColor),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ChatTabButton(
                      label: '개인채팅',
                      selected: _selectedTabIndex == 0,
                      onTap: () => setState(() => _selectedTabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ChatTabButton(
                      label: '단체채팅',
                      selected: _selectedTabIndex == 1,
                      onTap: () => setState(() => _selectedTabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : rooms.isEmpty
                    ? Center(
                        child: Text(
                          _selectedTabIndex == 0
                              ? '아직 개인 채팅방이 없어요.\n모집글에서 채팅을 시작해보세요! 💬'
                              : '아직 참여한 단체 채팅방이 없어요.\n모집글의 팀 채팅에 참여해보세요! 👥',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: subTextColor, fontSize: 15, height: 1.6),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF00E676),
                        onRefresh: _loadRooms,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: rooms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            final lastMsg = room['_lastMessage'] as Map<String, dynamic>?;
                            final previewText = lastMsg == null
                                ? room['gathering_title'] ?? '모집글'
                                : lastMsg['message_type'] == 'image'
                                    ? '📷 사진'
                                    : lastMsg['message_type'] == 'schedule_proposal'
                                        ? '📅 일정 제안'
                                        : (lastMsg['content'] as String? ?? '');
                            final previewTime =
                                _formatPreviewTime(lastMsg?['created_at'] as String?);
                            final unreadCount =
                                _selectedTabIndex == 0 ? (room['_unreadCount'] as int? ?? 0) : 0;

                            final title = _selectedTabIndex == 0
                                ? _getOtherNickname(room)
                                : (room['gathering_title'] as String? ?? '단체 채팅');

                            return GestureDetector(
                              onTap: () async {
                                if (_selectedTabIndex == 0) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatRoomScreen(
                                        roomId: room['id'],
                                        otherUserNickname: _getOtherNickname(room),
                                        gatheringTitle: room['gathering_title'] ?? '모집글',
                                        otherUserId: _getOtherUserId(room),
                                      ),
                                    ),
                                  );
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupChatScreen(
                                        gatheringId: room['gathering_id'] as String? ?? '',
                                        gatheringTitle: room['gathering_title'] as String? ?? '단체 채팅',
                                        hostId: room['host_id'] as String? ?? '',
                                        hostNickname: room['host_nickname'] as String? ?? '팀장',
                                      ),
                                    ),
                                  );
                                }
                                _loadRooms();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (!isDarkMode)
                                      BoxShadow(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: isDarkMode
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey[200],
                                      child: Icon(
                                        _selectedTabIndex == 0 ? Icons.person : Icons.groups,
                                        color: subTextColor,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: textColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15),
                                                ),
                                              ),
                                              Text(
                                                previewTime,
                                                style: TextStyle(
                                                    color: subTextColor,
                                                    fontSize: 11),
                                              ),
                                              const SizedBox(width: 6),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                icon: Icon(Icons.more_vert,
                                                    size: 18,
                                                    color: subTextColor),
                                                onSelected: (value) {
                                                  if (value == 'leave') {
                                                    if (_selectedTabIndex == 0) {
                                                      _leaveDirectRoom(room['id'] as String);
                                                    } else {
                                                      _leaveGroupRoom(room);
                                                    }
                                                  }
                                                },
                                                itemBuilder: (ctx) => const [
                                                  PopupMenuItem<String>(
                                                    value: 'leave',
                                                    child: Text('채팅방 나가기'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  previewText,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: unreadCount > 0
                                                        ? textColor
                                                        : subTextColor,
                                                    fontSize: 13,
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w500
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (unreadCount > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF00E676),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '$unreadCount',
                                                    style: const TextStyle(
                                                      color: Colors.black,
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChatTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChatTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00E676) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.black
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

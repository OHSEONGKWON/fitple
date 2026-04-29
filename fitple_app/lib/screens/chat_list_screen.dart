import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  RealtimeChannel? _messageChannel;
  Set<String> _roomIds = {};

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

      final enriched = await Future.wait(
        all.map((room) => _enrichRoom(room, user.id)),
      );

      enriched.sort((a, b) {
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

      _roomIds = enriched.map((r) => r['id'] as String).toSet();

      if (mounted) {
        setState(() {
          _rooms = enriched;
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

  String _getOtherNickname(Map<String, dynamic> room) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id == room['host_id']) return room['guest_nickname'] ?? '상대방';
    return room['host_nickname'] ?? '상대방';
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _rooms.isEmpty
              ? Center(
                  child: Text(
                    '아직 채팅방이 없어요.\n모집글에서 채팅을 시작해보세요! 💬',
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
                    itemCount: _rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final otherNickname = _getOtherNickname(room);
                      final lastMsg =
                          room['_lastMessage'] as Map<String, dynamic>?;
                      final unreadCount = room['_unreadCount'] as int? ?? 0;

                      final previewText = lastMsg == null
                          ? room['gathering_title'] ?? '모집글'
                          : lastMsg['message_type'] == 'image'
                              ? '📷 사진'
                              : (lastMsg['content'] as String? ?? '');
                      final previewTime =
                          _formatPreviewTime(lastMsg?['created_at'] as String?);

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatRoomScreen(
                                roomId: room['id'],
                                otherUserNickname: otherNickname,
                                gatheringTitle:
                                    room['gathering_title'] ?? '모집글',
                              ),
                            ),
                          );
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
                                child: Icon(Icons.person,
                                    color: subTextColor, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          otherNickname,
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                        Text(
                                          previewTime,
                                          style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // 내가 host이거나 guest인 채팅방 모두 가져오기
      final hostRooms = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('host_id', user.id)
          .order('created_at', ascending: false);

      final guestRooms = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('guest_id', user.id)
          .order('created_at', ascending: false);

      final all = [
        ...List<Map<String, dynamic>>.from(hostRooms),
        ...List<Map<String, dynamic>>.from(guestRooms),
      ];
      // created_at 기준 정렬
      all.sort((a, b) =>
          (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      if (mounted) setState(() { _rooms = all; _isLoading = false; });
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
    if (user?.id == room['host_id']) {
      return room['guest_nickname'] ?? '상대방';
    }
    return room['host_nickname'] ?? '상대방';
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final otherNickname = _getOtherNickname(room);
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
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
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                                    Text(
                                      otherNickname,
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      room['gathering_title'] ?? '모집글',
                                      style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: subTextColor, size: 20),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String otherUserNickname;
  final String gatheringTitle;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.otherUserNickname,
    required this.gatheringTitle,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _messageController.clear();

    try {
      await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'sender_nickname':
            user.userMetadata?['display_name'] ?? user.email ?? '익명',
        'content': text,
      });

      // 새 메시지 도착 시 스크롤 맨 아래로
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final inputBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100]!;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserNickname,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.gatheringTitle,
              style: TextStyle(color: subTextColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00E676)),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      '첫 메시지를 보내보세요! 💬',
                      style: TextStyle(color: subTextColor, fontSize: 15),
                    ),
                  );
                }

                // 메시지 도착 시 스크롤 최하단
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == currentUserId;
                    return _MessageBubble(
                      message: msg['content'] ?? '',
                      isMe: isMe,
                      senderNickname: msg['sender_nickname'] ?? '',
                      createdAt: msg['created_at'] ?? '',
                      isDarkMode: isDarkMode,
                    );
                  },
                );
              },
            ),
          ),

          // 메시지 입력 영역
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                            color:
                                isDarkMode ? Colors.white30 : Colors.black38),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String senderNickname;
  final String createdAt;
  final bool isDarkMode;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderNickname,
    required this.createdAt,
    required this.isDarkMode,
  });

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subTextColor = isDarkMode ? Colors.white38 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[300],
              child: Icon(Icons.person,
                  size: 18,
                  color: isDarkMode ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(senderNickname,
                      style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(_formatTime(createdAt),
                          style: TextStyle(
                              color: subTextColor, fontSize: 11)),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF00E676)
                            : (isDarkMode
                                ? const Color(0xFF2C2C2C)
                                : Colors.grey[200]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isMe
                              ? Colors.black
                              : (isDarkMode
                                  ? Colors.white
                                  : Colors.black87),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(_formatTime(createdAt),
                          style: TextStyle(
                              color: subTextColor, fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

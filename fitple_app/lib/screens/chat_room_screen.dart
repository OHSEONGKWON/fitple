import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  StreamSubscription? _roomSubscription;

  String? _myRole;
  DateTime? _otherLastReadAt;
  Map<String, dynamic>? _replyToMessage;
  bool _isSendingImage = false;

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatRoomId = widget.roomId;
    _messagesStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true);
    _subscribeToRoom();
  }

  void _subscribeToRoom() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _roomSubscription = Supabase.instance.client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', widget.roomId)
        .listen((data) {
          if (!mounted || data.isEmpty) return;
          final room = data.first;

          final isHost = room['host_id'] == user.id;
          final role = isHost ? 'host' : 'guest';
          final otherReadAtStr = isHost
              ? room['guest_last_read_at'] as String?
              : room['host_last_read_at'] as String?;
          final otherReadAt = otherReadAtStr != null
              ? DateTime.tryParse(otherReadAtStr)
              : null;

          setState(() {
            _myRole = role;
            _otherLastReadAt = otherReadAt;
          });
          _updateLastReadAt(role);
        });
  }

  Future<void> _updateLastReadAt(String role) async {
    final col = role == 'host' ? 'host_last_read_at' : 'guest_last_read_at';
    await Supabase.instance.client
        .from('chat_rooms')
        .update({col: DateTime.now().toUtc().toIso8601String()})
        .eq('id', widget.roomId);
  }

  @override
  void dispose() {
    NotificationService.activeChatRoomId = null;
    _roomSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final reply = _replyToMessage;
    _messageController.clear();
    setState(() => _replyToMessage = null);

    try {
      await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'sender_nickname':
            user.userMetadata?['display_name'] ?? user.email ?? '익명',
        'content': text,
        'message_type': 'text',
        if (reply != null) 'reply_to_message_id': reply['id'],
        if (reply != null)
          'reply_to_content': reply['message_type'] == 'image'
              ? '📷 사진'
              : (reply['content'] ?? ''),
      });

      if (_myRole != null) _updateLastReadAt(_myRole!);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSendingImage = true);

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final fileName =
          '${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Supabase.instance.client.storage
          .from('chat-images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              upsert: true,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('chat-images')
          .getPublicUrl(fileName);

      final reply = _replyToMessage;
      setState(() => _replyToMessage = null);

      await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'sender_nickname':
            user.userMetadata?['display_name'] ?? user.email ?? '익명',
        'content': '',
        'message_type': 'image',
        'image_url': imageUrl,
        if (reply != null) 'reply_to_message_id': reply['id'],
        if (reply != null)
          'reply_to_content': reply['message_type'] == 'image'
              ? '📷 사진'
              : (reply['content'] ?? ''),
      });

      if (_myRole != null) _updateLastReadAt(_myRole!);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      }
    });
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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_myRole != null) _updateLastReadAt(_myRole!);
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == currentUserId;

                    bool isRead = false;
                    if (isMe && _otherLastReadAt != null) {
                      final msgTime =
                          DateTime.tryParse(msg['created_at'] ?? '');
                      if (msgTime != null) {
                        isRead = !_otherLastReadAt!.isBefore(msgTime);
                      }
                    }

                    // 답장 원본 메시지의 닉네임 조회
                    String? replySenderNickname;
                    if (msg['reply_to_message_id'] != null) {
                      final original = messages.firstWhere(
                        (m) => m['id'] == msg['reply_to_message_id'],
                        orElse: () => {},
                      );
                      replySenderNickname =
                          original['sender_nickname'] as String?;
                    }

                    return GestureDetector(
                      onLongPress: () =>
                          setState(() => _replyToMessage = msg),
                      child: _MessageBubble(
                        message: msg['content'] ?? '',
                        isMe: isMe,
                        isRead: isRead,
                        senderNickname: msg['sender_nickname'] ?? '',
                        createdAt: msg['created_at'] ?? '',
                        isDarkMode: isDarkMode,
                        messageType: msg['message_type'] ?? 'text',
                        imageUrl: msg['image_url'] as String?,
                        replyContent: msg['reply_to_content'] as String?,
                        replySenderNickname: replySenderNickname,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 답장 미리보기 바
          if (_replyToMessage != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: inputBg,
                border: const Border(
                  top: BorderSide(color: Color(0xFF00E676), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        borderRadius: BorderRadius.circular(2),
                      )),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyToMessage!['sender_nickname'] ?? '',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _replyToMessage!['message_type'] == 'image'
                              ? '📷 사진'
                              : (_replyToMessage!['content'] ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _replyToMessage = null),
                    child: Icon(Icons.close,
                        size: 18, color: subTextColor),
                  ),
                ],
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
                  // 이미지 전송 버튼
                  GestureDetector(
                    onTap: _isSendingImage ? null : _sendImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: inputBg,
                        shape: BoxShape.circle,
                      ),
                      child: _isSendingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00E676)),
                            )
                          : Icon(Icons.image_outlined,
                              color: subTextColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.white30
                                : Colors.black38),
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
  final bool isRead;
  final String senderNickname;
  final String createdAt;
  final bool isDarkMode;
  final String messageType;
  final String? imageUrl;
  final String? replyContent;
  final String? replySenderNickname;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.senderNickname,
    required this.createdAt,
    required this.isDarkMode,
    this.messageType = 'text',
    this.imageUrl,
    this.replyContent,
    this.replySenderNickname,
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
    final bubbleColor = isMe
        ? const Color(0xFF00E676)
        : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200]!);
    final textColor =
        isMe ? Colors.black : (isDarkMode ? Colors.white : Colors.black87);

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
                  // 읽음 표시 + 시간 (내 메시지 왼쪽)
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isRead)
                            const Text(
                              '1',
                              style: TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(_formatTime(createdAt),
                              style: TextStyle(
                                  color: subTextColor, fontSize: 11)),
                        ],
                      ),
                    ),
                  // 말풍선
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.65,
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 답장 박스
                          if (replyContent != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                  10, 8, 10, 8),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.08),
                                border: Border(
                                  left: BorderSide(
                                    color: isMe
                                        ? Colors.black38
                                        : const Color(0xFF00E676),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (replySenderNickname != null)
                                    Text(
                                      replySenderNickname!,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.black54
                                            : const Color(0xFF00E676),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  Text(
                                    replyContent!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.black54
                                          : (isDarkMode
                                              ? Colors.white54
                                              : Colors.black54),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // 본문 (이미지 또는 텍스트)
                          if (messageType == 'image' &&
                              imageUrl != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 260),
                              child: Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder:
                                    (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 160,
                                    color: bubbleColor,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF00E676),
                                          strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => Container(
                                  height: 100,
                                  color: bubbleColor,
                                  child: Icon(Icons.broken_image,
                                      color: subTextColor),
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Text(
                                message,
                                style: TextStyle(
                                    color: textColor, fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 시간 (상대방 메시지 오른쪽)
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

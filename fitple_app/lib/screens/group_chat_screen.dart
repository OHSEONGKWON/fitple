import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupChatScreen extends StatefulWidget {
  final String gatheringId;
  final String gatheringTitle;
  final String hostId;
  final String hostNickname;

  const GroupChatScreen({
    super.key,
    required this.gatheringId,
    required this.gatheringTitle,
    required this.hostId,
    required this.hostNickname,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  String? _roomId;
  bool _isJoining = true;

  String get _myId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _myNickname =>
      Supabase.instance.client.auth.currentUser?.userMetadata?['display_name']
          as String? ??
      Supabase.instance.client.auth.currentUser?.email?.split('@').first ??
      '사용자';

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    try {
      // 이미 존재하는 방 조회
      final existing = await Supabase.instance.client
          .from('group_chat_rooms')
          .select('id')
          .eq('gathering_id', widget.gatheringId)
          .maybeSingle();

      String roomId;
      if (existing != null) {
        roomId = existing['id'] as String;
      } else {
        // 방 생성 (호스트 또는 첫 진입자)
        final created = await Supabase.instance.client
            .from('group_chat_rooms')
            .insert({
              'gathering_id': widget.gatheringId,
              'gathering_title': widget.gatheringTitle,
              'host_id': widget.hostId,
            })
            .select('id')
            .single();
        roomId = created['id'] as String;
      }

      // 메시지 스트림 구독
      _messagesStream = Supabase.instance.client
          .from('group_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _roomId = roomId;
          _isJoining = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('채팅방 입장 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _roomId == null) return;
    _controller.clear();
    try {
      await Supabase.instance.client.from('group_messages').insert({
        'room_id': _roomId,
        'user_id': _myId,
        'user_nickname': _myNickname,
        'content': content,
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white54 : Colors.black45;
    final bgColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final myBubbleColor = const Color(0xFF00E676);
    final otherBubbleColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.gatheringTitle,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis),
            Text('단체 채팅',
                style: TextStyle(color: subColor, fontSize: 12)),
          ],
        ),
      ),
      body: _isJoining
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _roomId == null
              ? Center(
                  child: Text('채팅방에 입장할 수 없어요',
                      style: TextStyle(color: subColor)))
              : Column(
                  children: [
                    // 메시지 목록
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF00E676)));
                          }
                          final messages = snapshot.data ?? [];
                          if (messages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.forum_outlined,
                                      size: 56, color: subColor),
                                  const SizedBox(height: 12),
                                  Text('첫 메시지를 보내보세요!',
                                      style: TextStyle(
                                          color: subColor, fontSize: 15)),
                                ],
                              ),
                            );
                          }

                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _scrollToBottom());

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg['user_id'] == _myId;
                              final nickname =
                                  msg['user_nickname'] as String? ?? '사용자';
                              final content = msg['content'] as String? ?? '';
                              final time =
                                  _formatTime(msg['created_at'] as String?);

                              // 날짜 구분선
                              Widget? dateSeparator;
                              if (index == 0) {
                                final dt = DateTime.parse(
                                        msg['created_at'] as String)
                                    .toLocal();
                                dateSeparator = _DateChip(
                                    date: '${dt.month}월 ${dt.day}일');
                              } else {
                                final prev = messages[index - 1];
                                final prevDt = DateTime.parse(
                                        prev['created_at'] as String)
                                    .toLocal();
                                final curDt = DateTime.parse(
                                        msg['created_at'] as String)
                                    .toLocal();
                                if (prevDt.day != curDt.day) {
                                  dateSeparator = _DateChip(
                                      date:
                                          '${curDt.month}월 ${curDt.day}일');
                                }
                              }

                              return Column(
                                children: [
                                  ?dateSeparator,
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 3),
                                    child: Row(
                                      mainAxisAlignment: isMe
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (!isMe) ...[
                                          CircleAvatar(
                                            radius: 15,
                                            backgroundColor: const Color(
                                                    0xFF00E676)
                                                .withValues(alpha: 0.2),
                                            child: const Icon(Icons.person,
                                                size: 17,
                                                color: Color(0xFF00E676)),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Column(
                                          crossAxisAlignment: isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                        bottom: 3),
                                                child: Text(nickname,
                                                    style: TextStyle(
                                                        color: subColor,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (isMe)
                                                  Text(time,
                                                      style: TextStyle(
                                                          color: subColor,
                                                          fontSize: 10)),
                                                if (isMe)
                                                  const SizedBox(width: 4),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 240),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? myBubbleColor
                                                        : otherBubbleColor,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          const Radius.circular(
                                                              16),
                                                      topRight:
                                                          const Radius.circular(
                                                              16),
                                                      bottomLeft:
                                                          Radius.circular(
                                                              isMe ? 16 : 4),
                                                      bottomRight:
                                                          Radius.circular(
                                                              isMe ? 4 : 16),
                                                    ),
                                                    boxShadow: [
                                                      if (!isDarkMode)
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                  alpha: 0.06),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                              0, 1),
                                                        ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    content,
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.black
                                                          : textColor,
                                                      fontSize: 14,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                                if (!isMe)
                                                  const SizedBox(width: 4),
                                                if (!isMe)
                                                  Text(time,
                                                      style: TextStyle(
                                                          color: subColor,
                                                          fontSize: 10)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (isMe) const SizedBox(width: 6),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // 입력창
                    Container(
                      color: isDarkMode
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 8,
                        top: 8,
                        bottom:
                            MediaQuery.of(context).viewInsets.bottom + 8,
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2C2C2C)
                                      : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  style: TextStyle(
                                      color: textColor, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: '메시지 보내기...',
                                    hintStyle:
                                        TextStyle(color: subColor),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 10),
                                  ),
                                  onSubmitted: (_) => _send(),
                                  textInputAction: TextInputAction.send,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _send,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded,
                                    color: Colors.black, size: 18),
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

class _DateChip extends StatelessWidget {
  final String date;
  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(date,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

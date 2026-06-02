import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String otherUserNickname;
  final String gatheringTitle;
  final String? otherUserId;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.otherUserNickname,
    required this.gatheringTitle,
    this.otherUserId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  StreamSubscription? _roomSubscription;
  Timer? _messagesPollingTimer;

  String? _myRole;
  DateTime? _otherLastReadAt;
  DateTime? _lastReadAtUpdate;
  Map<String, dynamic>? _replyToMessage;
  bool _isSendingImage = false;
  bool _isSendingSchedule = false;
  Timer? _readStatusTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatRoomId = widget.roomId;
    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        _mergeMessages(List<Map<String, dynamic>>.from(data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_myRole != null) _updateLastReadAt(_myRole!);
          _scrollToBottom();
        });
      }
    });
    _startMessagesPollingFallback();
    _fetchMessagesOnce();
    _subscribeToRoom();
    // 즉시 읽음 처리 + 상대방 읽음 상태 주기적 갱신
    _initAndMarkRead();
    _readStatusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshOtherReadAt(),
    );
  }

  /// 채팅방 진입 시 즉시 내 읽음 시각 업데이트 & 상대방 읽음 시각 로드
  Future<void> _initAndMarkRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final room = await Supabase.instance.client
          .from('chat_rooms')
          .select('host_id, host_last_read_at, guest_last_read_at')
          .eq('id', widget.roomId)
          .single();
      final isHost = room['host_id'] == user.id;
      final role = isHost ? 'host' : 'guest';
      final otherReadAtStr = isHost
          ? room['guest_last_read_at'] as String?
          : room['host_last_read_at'] as String?;
      if (mounted) {
        setState(() {
          _myRole = role;
          _otherLastReadAt = otherReadAtStr != null
              ? DateTime.tryParse(otherReadAtStr)
              : null;
        });
      }
      await _updateLastReadAt(role);
    } catch (_) {}
  }

  /// 상대방이 읽었는지 주기적으로 확인 (Realtime 미활성 환경 대응)
  Future<void> _refreshOtherReadAt() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final room = await Supabase.instance.client
          .from('chat_rooms')
          .select('host_id, host_last_read_at, guest_last_read_at')
          .eq('id', widget.roomId)
          .single();
      final isHost = room['host_id'] == user.id;
      final otherReadAtStr = isHost
          ? room['guest_last_read_at'] as String?
          : room['host_last_read_at'] as String?;
      final otherReadAt =
          otherReadAtStr != null ? DateTime.tryParse(otherReadAtStr) : null;
      // millisecond 기준 비교로 DateTime 동등성 문제 방지
      final prevMs = _otherLastReadAt?.millisecondsSinceEpoch;
      final newMs = otherReadAt?.millisecondsSinceEpoch;
      if (mounted && prevMs != newMs) {
        setState(() => _otherLastReadAt = otherReadAt);
      }
    } catch (_) {}
  }

  void _startMessagesPollingFallback() {
    _messagesPollingTimer?.cancel();
    _messagesPollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _fetchMessagesOnce();
        _fetchRoomOnce();
      },
    );
  }

  Future<void> _fetchMessagesOnce() async {
    try {
      final rows = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true)
          .limit(500);
      if (!mounted) return;
      _mergeMessages(List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _fetchRoomOnce() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('id', widget.roomId)
          .maybeSingle();
      if (!mounted || data == null) return;
      final isHost = data['host_id'] == user.id;
      final role = isHost ? 'host' : 'guest';
      final otherReadAtStr = isHost
          ? data['guest_last_read_at'] as String?
          : data['host_last_read_at'] as String?;
      final otherReadAt =
          otherReadAtStr != null ? DateTime.tryParse(otherReadAtStr) : null;

      bool needsRebuild = false;
      if (_myRole != role) needsRebuild = true;
      if (otherReadAt != _otherLastReadAt) needsRebuild = true;
      if (needsRebuild && mounted) {
        setState(() {
          _myRole = role;
          _otherLastReadAt = otherReadAt;
        });
      }

      // 채팅방에 있는 동안 내 읽음 시각을 주기적으로 갱신 (채팅 목록 뱃지 해소)
      _updateLastReadAt(role);
    } catch (_) {}
  }

  void _upsertMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final incomingId = msg['id']?.toString();
    setState(() {
      final idx = incomingId == null
          ? -1
          : _messages.indexWhere((m) => m['id']?.toString() == incomingId);
      if (idx >= 0) {
        _messages[idx] = msg;
      } else {
        _messages.add(msg);
      }
      _messages.sort((a, b) =>
          (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
    });
  }

  void _mergeMessages(List<Map<String, dynamic>> incoming) {
    if (!mounted) return;
    setState(() {
      final byId = <String, Map<String, dynamic>>{};
      for (final m in _messages) {
        final id = m['id']?.toString();
        if (id != null) byId[id] = m;
      }
      for (final m in incoming) {
        final id = m['id']?.toString();
        if (id != null) {
          byId[id] = m;
        }
      }
      _messages = byId.values.toList()
        ..sort((a, b) =>
            (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
    });
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
    final now = DateTime.now();
    if (_lastReadAtUpdate != null &&
        now.difference(_lastReadAtUpdate!) < const Duration(seconds: 2)) {
      return;
    }
    _lastReadAtUpdate = now;
    final col = role == 'host' ? 'host_last_read_at' : 'guest_last_read_at';
    try {
      await Supabase.instance.client
          .from('chat_rooms')
          .update({col: now.toUtc().toIso8601String()})
          .eq('id', widget.roomId);
    } catch (e) {
      // 실패 시 디버그용 (RLS 정책 미설정 가능성)
      debugPrint('_updateLastReadAt 실패: $e');
    }
  }

  Future<void> _leaveChatRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('이 개인 채팅방을 나가시겠어요?\n채팅방 목록에서 사라집니다.'),
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

    // 폴링 타이머를 먼저 중단해 삭제 중 재요청 방지
    _messagesPollingTimer?.cancel();

    try {
      // 메시지 먼저 삭제 (FK 제약 해소)
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('room_id', widget.roomId);

      // 채팅방 삭제 (삭제된 row 반환으로 성공 여부 확인)
      final deleted = await Supabase.instance.client
          .from('chat_rooms')
          .delete()
          .eq('id', widget.roomId)
          .select();

      if (!mounted) return;

      if ((deleted as List).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('나가기 실패: 권한이 없거나 이미 삭제된 채팅방입니다.\nSupabase chat_rooms DELETE 정책을 확인하세요.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // 재시작 (폴링 복원)
      _startMessagesPollingFallback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 나가기 실패: ${e.message}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _startMessagesPollingFallback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 나가기 실패: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    NotificationService.activeChatRoomId = null;
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    _messagesPollingTimer?.cancel();
    _readStatusTimer?.cancel();
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
      final inserted = await Supabase.instance.client.from('messages').insert({
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
      }).select().single();

      _upsertMessage(Map<String, dynamic>.from(inserted));

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

      final inserted = await Supabase.instance.client.from('messages').insert({
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
      }).select().single();

      _upsertMessage(Map<String, dynamic>.from(inserted));

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

  String _formatScheduledAt(DateTime dt) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[dt.weekday - 1];
    final hour = dt.hour;
    final ampm = hour < 12 ? '오전' : '오후';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}월 ${dt.day}일 ($wd) $ampm $h:$m';
  }

  Future<void> _proposeSchedule() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;
          final fieldColor =
              isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('일정 제안',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '일정 제목 (예: 헬스장 같이가요)',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: fieldColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now()
                                  .add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                              builder: (_, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: ColorScheme.fromSeed(
                                      seedColor: const Color(0xFF00E676)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setSheet(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: fieldColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Color(0xFF00E676)),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDate == null
                                      ? '날짜 선택'
                                      : '${selectedDate!.month}/${selectedDate!.day}',
                                  style: TextStyle(
                                      color: textColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime:
                                  const TimeOfDay(hour: 10, minute: 0),
                              builder: (_, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: ColorScheme.fromSeed(
                                      seedColor: const Color(0xFF00E676)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setSheet(() => selectedTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: fieldColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: Color(0xFF00E676)),
                                const SizedBox(width: 8),
                                Text(
                                  selectedTime == null
                                      ? '시간 선택'
                                      : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      color: textColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '장소 (선택)',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: fieldColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: Color(0xFF00E676), size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty ||
                            selectedDate == null ||
                            selectedTime == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('제목, 날짜, 시간을 모두 입력해주세요')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('일정 제안 보내기',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final savedTitle = titleController.text.trim();
    final savedLocation = locationController.text.trim();
    titleController.dispose();
    locationController.dispose();

    if (confirmed != true ||
        selectedDate == null ||
        selectedTime == null ||
        savedTitle.isEmpty) {
      return;
    }

    final scheduledAt = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    await _sendScheduleProposal(
        savedTitle, scheduledAt, savedLocation.isEmpty ? null : savedLocation);
  }

  Future<void> _sendScheduleProposal(
      String title, DateTime scheduledAt, String? location) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_isSendingSchedule) return;

    setState(() => _isSendingSchedule = true);
    final myNickname =
        user.userMetadata?['display_name'] as String? ?? '나';

    try {
      final scheduleData = await Supabase.instance.client
          .from('schedules')
          .insert({
            'room_id': widget.roomId,
            'proposer_id': user.id,
            'proposer_nickname': myNickname,
            if (widget.otherUserId != null) 'responder_id': widget.otherUserId,
            'responder_nickname': widget.otherUserNickname,
            'title': title,
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
            'location': location,
            'status': 'pending',
          })
          .select()
          .single();

      final scheduleId = scheduleData['id'] as String;
      final contentLines = [
        title,
        '📅 ${_formatScheduledAt(scheduledAt)}',
        if (location != null) '📍 $location',
      ];

      final inserted = await Supabase.instance.client.from('messages').insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'sender_nickname': myNickname,
        'content': contentLines.join('\n'),
        'message_type': 'schedule_proposal',
        'schedule_id': scheduleId,
        'schedule_status': 'pending',
      }).select().single();

      _upsertMessage(Map<String, dynamic>.from(inserted));

      if (_myRole != null) _updateLastReadAt(_myRole!);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('일정 전송 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingSchedule = false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: '나가기',
            onPressed: _leaveChatRoom,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      '첫 메시지를 보내보세요! 💬',
                      style: TextStyle(color: subTextColor, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == currentUserId;

                      bool isRead = false;
                      if (isMe && _otherLastReadAt != null) {
                        final msgTime =
                            DateTime.tryParse(msg['created_at'] ?? '');
                        if (msgTime != null) {
                          isRead = !_otherLastReadAt!.isBefore(msgTime);
                        }
                      }

                      // 일정 제안 버블
                      if (msg['message_type'] == 'schedule_proposal') {
                        return GestureDetector(
                          onLongPress: () =>
                              setState(() => _replyToMessage = msg),
                          child: _ScheduleProposalBubble(
                            message: msg,
                            isMe: isMe,
                            isDarkMode: isDarkMode,
                          ),
                        );
                      }

                      // 답장 원본 메시지의 닉네임 조회
                      String? replySenderNickname;
                      if (msg['reply_to_message_id'] != null) {
                        final original = _messages.firstWhere(
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
                  // 일정 제안 버튼
                  GestureDetector(
                    onTap: _isSendingSchedule ? null : _proposeSchedule,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: inputBg,
                        shape: BoxShape.circle,
                      ),
                      child: _isSendingSchedule
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00E676)),
                            )
                          : Icon(Icons.calendar_month_outlined,
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
                                errorBuilder: (context, e, stack) => Container(
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

class _ScheduleProposalBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDarkMode;

  const _ScheduleProposalBubble({
    required this.message,
    required this.isMe,
    required this.isDarkMode,
  });

  @override
  State<_ScheduleProposalBubble> createState() =>
      _ScheduleProposalBubbleState();
}

class _ScheduleProposalBubbleState extends State<_ScheduleProposalBubble> {
  late String _status;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _status =
        widget.message['schedule_status'] as String? ?? 'pending';
  }

  @override
  void didUpdateWidget(_ScheduleProposalBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newStatus =
        widget.message['schedule_status'] as String? ?? 'pending';
    if (newStatus != _status && !_isUpdating) {
      setState(() => _status = newStatus);
    }
  }

  Future<void> _respond(String status) async {
    final scheduleId = widget.message['schedule_id'] as String?;
    final messageId = widget.message['id'] as String?;
    if (scheduleId == null || _isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await Future.wait([
        Supabase.instance.client
            .from('schedules')
            .update({'status': status}).eq('id', scheduleId),
        if (messageId != null)
          Supabase.instance.client
              .from('messages')
              .update({'schedule_status': status}).eq('id', messageId),
      ]);
      if (mounted) setState(() { _status = status; _isUpdating = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final isMe = widget.isMe;
    final isDarkMode = widget.isDarkMode;
    final content = widget.message['content'] as String? ?? '';
    final senderNickname = widget.message['sender_nickname'] as String? ?? '';
    final subColor = isDarkMode ? Colors.white38 : Colors.black38;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'accepted':
        statusColor = const Color(0xFF00E676);
        statusText = '✓ 수락됨';
      case 'declined':
        statusColor = Colors.grey;
        statusText = '✗ 거절됨';
      default:
        statusColor = Colors.orange;
        statusText = '대기중';
    }

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
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(senderNickname,
                        style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF2C2C2C)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month,
                                    color: Color(0xFF00E676), size: 15),
                                const SizedBox(width: 5),
                                Text(
                                  '일정 제안',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusText,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        if (!isMe && status == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isUpdating
                                      ? null
                                      : () => _respond('declined'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white10
                                          : Colors.grey[200],
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text('거절',
                                          style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white60
                                                  : Colors.black54,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _isUpdating
                                      ? null
                                      : () => _respond('accepted'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Text('수락',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

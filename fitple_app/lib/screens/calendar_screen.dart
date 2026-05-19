import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('schedules')
          .select()
          .or('proposer_id.eq.${user.id},responder_id.eq.${user.id}')
          .order('scheduled_at', ascending: true);
      if (mounted) {
        setState(() {
          _schedules = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _schedulesForDay(DateTime day) {
    return _schedules.where((s) {
      final dt =
          DateTime.tryParse(s['scheduled_at'] as String? ?? '')?.toLocal();
      return dt != null &&
          dt.year == day.year &&
          dt.month == day.month &&
          dt.day == day.day;
    }).toList();
  }


  List<Map<String, dynamic>> get _displaySchedules {
    if (_selectedDay != null) {
      return _schedulesForDay(_selectedDay!);
    }
    final now = DateTime.now();
    return _schedules
        .where((s) {
          final dt = DateTime.tryParse(s['scheduled_at'] as String? ?? '')
              ?.toLocal();
          if (dt == null) return false;
          if ((s['status'] as String? ?? '') == 'declined') return false;
          return !dt.isBefore(now.subtract(const Duration(hours: 1)));
        })
        .toList();
  }

  void _prevMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
        _selectedDay = null;
      });

  void _nextMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
        _selectedDay = null;
      });

  String _formatScheduledAt(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[dt.weekday - 1];
    final hour = dt.hour;
    final ampm = hour < 12 ? '오전' : '오후';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}월 ${dt.day}일 ($wd) $ampm $h:$m';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF00E676);
      case 'declined':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '수락됨';
      case 'declined':
        return '거절됨';
      default:
        return '대기중';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor =
        isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F8F8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        title: Text(
          '   일정 캘린더',
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: subTextColor),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : RefreshIndicator(
              color: const Color(0xFF00E676),
              onRefresh: _loadSchedules,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendar card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isDarkMode)
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Month navigation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon:
                                    Icon(Icons.chevron_left, color: textColor),
                                onPressed: _prevMonth,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Text(
                                '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon:
                                    Icon(Icons.chevron_right, color: textColor),
                                onPressed: _nextMonth,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Weekday headers
                          Row(
                            children: ['일', '월', '화', '수', '목', '금', '토']
                                .map((d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: TextStyle(
                                            color: d == '일'
                                                ? Colors.red[300]
                                                : d == '토'
                                                    ? Colors.blue[300]
                                                    : subTextColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          _buildCalendarGrid(isDarkMode, textColor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _selectedDay != null
                            ? '${_selectedDay!.month}월 ${_selectedDay!.day}일 일정'
                            : '다가오는 일정',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_displaySchedules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _selectedDay != null
                                ? '이 날 일정이 없어요'
                                : '예정된 일정이 없어요\n채팅에서 일정을 잡아보세요! 📅',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: subTextColor,
                                fontSize: 14,
                                height: 1.6),
                          ),
                        ),
                      )
                    else
                      ..._displaySchedules
                          .map((s) => _ScheduleCard(
                                schedule: s,
                                isDarkMode: isDarkMode,
                                cardColor: cardColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                formatScheduledAt: _formatScheduledAt,
                                statusColor: _statusColor,
                                statusLabel: _statusLabel,
                              )),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCalendarGrid(bool isDarkMode, Color textColor) {
    final firstWeekday = _focusedMonth.weekday % 7;
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isToday = today.year == date.year &&
          today.month == date.month &&
          today.day == date.day;
      final isSelected = _selectedDay?.year == date.year &&
          _selectedDay?.month == date.month &&
          _selectedDay?.day == date.day;
      final daySchedules = _schedulesForDay(date)
          .where((s) => (s['status'] as String? ?? '') != 'declined')
          .toList();

      cells.add(GestureDetector(
        onTap: () =>
            setState(() => _selectedDay = isSelected ? null : date),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00E676), width: 1.5),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 날짜 숫자
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isToday && !isSelected
                      ? const Color(0xFF00E676).withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(
                          color: const Color(0xFF00E676), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isToday
                          ? const Color(0xFF00E676)
                          : isSelected
                              ? const Color(0xFF00B050)
                              : textColor,
                      fontSize: 12,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // 일정 칩들
              ...daySchedules.take(2).map((s) {
                final status = s['status'] as String? ?? 'pending';
                Color chipColor;
                switch (status) {
                  case 'accepted':
                    chipColor = const Color(0xFF00E676);
                  case 'declined':
                    chipColor = Colors.grey;
                  default:
                    chipColor = Colors.orange;
                }
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    s['title'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 8,
                      color: chipColor,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              if (daySchedules.length > 2)
                Text(
                  '+${daySchedules.length - 2}',
                  style: TextStyle(
                    fontSize: 8,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.55,
      children: cells,
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final String Function(String?) formatScheduledAt;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  const _ScheduleCard({
    required this.schedule,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.formatScheduledAt,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final status = schedule['status'] as String? ?? 'pending';
    final title = schedule['title'] as String? ?? '일정';
    final location = schedule['location'] as String?;
    final scheduledAt = schedule['scheduled_at'] as String?;
    final user = Supabase.instance.client.auth.currentUser;
    final isProposer = schedule['proposer_id'] == user?.id;
    final otherNickname = isProposer
        ? (schedule['responder_nickname'] as String? ?? '상대방')
        : (schedule['proposer_nickname'] as String? ?? '상대방');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center,
                color: statusColor(status), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  '📅 ${formatScheduledAt(scheduledAt)}',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                if (location != null && location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('📍 $location',
                      style: TextStyle(color: subTextColor, fontSize: 12)),
                ],
                const SizedBox(height: 2),
                Text('👤 $otherNickname',
                    style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusLabel(status),
              style: TextStyle(
                color: statusColor(status),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

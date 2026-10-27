import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/data_service.dart';
import '../utils.dart';

/// 日历页面：纪念日 + 日程 + 经期提醒
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DataService get ds => DataService.instance;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // ========== 数据访问（全部来自 DataService，自动本地保存 + 云端同步）==========
  List<Map<String, dynamic>> get _anniversaries => ds.anniversaries;
  List<Map<String, dynamic>> get _schedules => ds.schedules;
  List<Map<String, dynamic>> get _periods => ds.periods;

  /// 判断某天是否落在一条经期记录覆盖的区间内
  bool _isDayInPeriod(DateTime day, Map<String, dynamic> item) {
    final start = parseDate(item['start'].toString());
    final duration = (item['duration'] as num?)?.toInt() ?? 0;
    final end = start.add(Duration(days: duration - 1));
    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool _isPeriodDay(DateTime day) {
    return _periods.any((item) => _isDayInPeriod(day, item));
  }

  bool _hasAnniversary(DateTime day) {
    return _anniversaries.any(
      (item) => isSameDay(parseDate(item['date'].toString()), day),
    );
  }

  bool _hasSchedule(DateTime day) {
    return _schedules.any(
      (item) => isSameDay(parseDate(item['date'].toString()), day),
    );
  }

  List<Map<String, dynamic>> _getDayAnniversaries(DateTime? day) {
    if (day == null) return [];
    return _anniversaries
        .where((item) => isSameDay(parseDate(item['date'].toString()), day))
        .toList();
  }

  List<Map<String, dynamic>> _getDaySchedules(DateTime? day) {
    if (day == null) return [];
    return _schedules
        .where((item) => isSameDay(parseDate(item['date'].toString()), day))
        .toList();
  }

  // ========== 添加弹窗 ==========
  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
              title: const Text('添加纪念日'),
              onTap: () {
                Navigator.pop(context);
                _showAddAnniversaryDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Colors.lightBlue),
              title: const Text('添加日程'),
              onTap: () {
                Navigator.pop(context);
                _showAddScheduleDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.redAccent),
              title: const Text('记录经期'),
              onTap: () {
                Navigator.pop(context);
                _showAddPeriodDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAnniversaryDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加纪念日'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：在一起第一天'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.isNotEmpty && _selectedDay != null) {
      await ds.addAnniversary(controller.text.trim(), _selectedDay!);
      _toast('已保存纪念日');
    }
  }

  Future<void> _showAddScheduleDialog() async {
    final titleController = TextEditingController();
    TimeOfDay start = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 13, minute: 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加日程'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '日程名称，如：看电影'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: start,
                        );
                        if (t != null) setDialogState(() => start = t);
                      },
                      child: Text('开始 ${_fmtTime(start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: end,
                        );
                        if (t != null) setDialogState(() => end = t);
                      },
                      child: Text('结束 ${_fmtTime(end)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && titleController.text.isNotEmpty && _selectedDay != null) {
      await ds.addSchedule(
        titleController.text.trim(),
        _fmtTime(start),
        _selectedDay!,
        endTime: _fmtTime(end),
      );
      _toast('已保存日程，到点会提醒你');
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _showAddPeriodDialog() async {
    final durationController = TextEditingController(text: '5');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录经期'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('开始日期：${_selectedDay?.month}月${_selectedDay?.day}日'),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(hintText: '持续天数'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && _selectedDay != null) {
      final days = int.tryParse(durationController.text) ?? 5;
      await ds.addPeriod(_selectedDay!, days < 1 ? 1 : days);
      _toast('已记录经期');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _showDeleteConfirm(String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.lightBlue,
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddMenu),
        ],
      ),
      body: ListenableBuilder(
        listenable: ds,
        builder: (context, _) {
          final dayAnniversaries = _getDayAnniversaries(_selectedDay);
          final daySchedules = _getDaySchedules(_selectedDay);
          final isPeriod = _selectedDay != null && _isPeriodDay(_selectedDay!);
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildDateSelector(),
                _buildCalendarCard(),
                _buildDetailCard(dayAnniversaries, daySchedules, isPeriod),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    final selected = _selectedDay ?? DateTime.now();
    final years = List.generate(16, (i) => 2020 + i);
    final months = List.generate(12, (i) => i + 1);
    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final days = List.generate(daysInMonth, (i) => i + 1);

    int clampDay(int y, int m, int d) {
      final maxD = DateTime(y, m + 1, 0).day;
      return d > maxD ? maxD : d;
    }

    void pick(int y, int m, int d) {
      final dt = DateTime(y, m, clampDay(y, m, d));
      setState(() {
        _selectedDay = dt;
        _focusedDay = dt;
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _dropdown(
              years,
              selected.year,
              (y) => pick(y, selected.month, selected.day),
              '年',
            ),
          ),
          Expanded(
            child: _dropdown(
              months,
              selected.month,
              (m) => pick(selected.year, m, selected.day),
              '月',
            ),
          ),
          Expanded(
            child: _dropdown(
              days,
              selected.day,
              (d) => pick(selected.year, selected.month, d),
              '日',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    List<int> items,
    int value,
    ValueChanged<int> onChanged,
    String suffix,
  ) {
    final safe = items.contains(value) ? value : items.first;
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: safe,
        isExpanded: true,
        alignment: Alignment.center,
        items: items
            .map((v) => DropdownMenuItem(value: v, child: Text('$v$suffix')))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            final markers = <Widget>[];
            if (_isPeriodDay(day)) {
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }
            if (_hasAnniversary(day)) {
              markers.add(_dot(Colors.pinkAccent));
            }
            if (_hasSchedule(day)) {
              markers.add(_dot(Colors.lightBlue));
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: markers,
            );
          },
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.lightBlue.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.lightBlue,
            shape: BoxShape.circle,
          ),
          weekendTextStyle: TextStyle(
            color: Colors.redAccent.withValues(alpha: 0.7),
          ),
          outsideDaysVisible: false,
        ),
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.lightBlue,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.lightBlue),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.lightBlue),
        ),
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildDetailCard(
    List<Map<String, dynamic>> dayAnniversaries,
    List<Map<String, dynamic>> daySchedules,
    bool isPeriod,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedDay?.year}年${_selectedDay?.month}月${_selectedDay?.day}日',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.lightBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (dayAnniversaries.isNotEmpty) ...[
            _sectionTitle('纪念日', Colors.pinkAccent),
            const SizedBox(height: 8),
            ...dayAnniversaries.map((item) => _deleteRow(
                  icon: Icons.favorite,
                  color: Colors.pinkAccent,
                  text: item['title'].toString(),
                  onDelete: () => _showDeleteConfirm(
                    '确定删除纪念日「${item['title']}」吗？',
                    () => ds.deleteAnniversary(item['id'].toString()),
                  ),
                )),
            const SizedBox(height: 12),
          ],
          if (daySchedules.isNotEmpty) ...[
            _sectionTitle('日程', Colors.lightBlue),
            const SizedBox(height: 8),
            ...daySchedules.map((item) => _deleteRow(
                  icon: Icons.access_time,
                  color: Colors.lightBlue,
                  text: '${item['time']}${(item['end_time']?.toString() ?? '').isNotEmpty ? '-${item['end_time']}' : ''}  ${item['title']}',
                  onDelete: () => _showDeleteConfirm(
                    '确定删除日程「${item['title']}」吗？',
                    () => ds.deleteSchedule(item['id'].toString()),
                  ),
                )),
            const SizedBox(height: 12),
          ],
          if (isPeriod) ...[
            _sectionTitle('经期', Colors.redAccent),
            const SizedBox(height: 8),
            _deleteRow(
              icon: Icons.water_drop,
              color: Colors.redAccent,
              text: '经期中，注意休息',
              onDelete: () {
                final day = _selectedDay;
                if (day == null) return;
                final idx = _periods.indexWhere(
                  (item) => _isDayInPeriod(day, item),
                );
                if (idx != -1) {
                  _showDeleteConfirm(
                    '确定删除这条经期记录吗？',
                    () => ds.deletePeriod(_periods[idx]['id'].toString()),
                  );
                }
              },
            ),
          ],
          if (dayAnniversaries.isEmpty && daySchedules.isEmpty && !isPeriod)
            const Text(
              '暂无安排',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
    );
  }

  Widget _deleteRow({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onDelete,
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
            const Icon(Icons.delete_outline, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}

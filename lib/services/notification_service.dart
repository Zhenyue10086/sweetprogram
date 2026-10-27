import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务：负责"消息栏提醒"（想你了 / 日程到点）。
///
/// 说明：极光推送在 App 前台时默认只回调、不弹通知栏；这里用本地通知兜底，
/// 保证 App 运行期间一定能看到消息栏提醒。
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _missYouChannelId = 'miss_you_channel';
  static const String _missYouChannelName = '想你了';
  static const String _scheduleChannelId = 'schedule_channel';
  static const String _scheduleChannelName = '日程提醒';

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // 时区数据
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      // 忽略：极端情况下退回默认
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    // Android 13+ 通知权限
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
    // Android 12+ 精确闹钟权限
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  Future<void> _ensure() async {
    if (!_inited) await init();
  }

  /// 立即弹出"想你了"通知
  Future<void> showMissYou(String from) async {
    await _ensure();
    await _plugin.show(
      id: 9001,
      title: '💌 TA 想你了',
      body: from.isEmpty ? '对方刚刚发来了一条想念 ❤️' : '「$from」刚刚发来了一条想念 ❤️',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _missYouChannelId,
          _missYouChannelName,
          channelDescription: '想你互动提醒',
          importance: Importance.max,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
    );
  }

  /// 安排一条定时通知（日程到点）
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _ensure();
    if (!when.isAfter(DateTime.now())) return;

    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _scheduleChannelId,
        _scheduleChannelName,
        channelDescription: '日程到点提醒',
        importance: Importance.max,
        priority: Priority.high,
        autoCancel: true,
      ),
    );
    final scheduledDate = tz.TZDateTime.from(when, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // 精确闹钟权限未授予时退回非精确，保证仍能提醒
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancel(int id) async {
    await _ensure();
    await _plugin.cancel(id: id);
  }
}

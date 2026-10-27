import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../utils.dart';
import 'cloud_service.dart';
import 'local_store.dart';
import 'notification_service.dart';
import 'push_service.dart';

/// 统一数据服务：内存状态 + 本地持久化 + CloudBase 云端同步 + 推送/通知。
///
/// 本地优先：
/// 1. 所有改动先写内存 + 本地 shared_preferences（没网也不丢）；
/// 2. 再"尽力而为"同步到 CloudBase；
/// 3. 启动时先读本地（秒开），后台再拉云端合并。
class DataService extends ChangeNotifier {
  DataService._();
  static final DataService instance = DataService._();

  // ===== 业务数据 =====
  List<Map<String, dynamic>> anniversaries = [];
  List<Map<String, dynamic>> schedules = [];
  List<Map<String, dynamic>> periods = [];
  List<Map<String, dynamic>> moments = [];
  List<Map<String, dynamic>> missYouEvents = [];
  List<Map<String, dynamic>> profiles = [];

  // ===== 设置 =====
  String nickname = '我';
  String togetherSince = '';
  String myProfileId = '';
  String myAvatar = '';
  String myRegId = '';

  // ===== 同步状态 =====
  bool loading = true;
  bool cloudAvailable = false;
  DateTime? lastSyncedAt;
  String syncMessage = '';

  // ===== "想你"未读 =====
  int missYouUnseenCount = 0;

  /// 点击推送通知后要切换到的底部 tab（2 = 互动）
  final ValueNotifier<int?> pendingTab = ValueNotifier<int?>(null);

  Set<String> _likedMomentIds = {};
  final Set<int> _scheduledNotifIds = {};

  // ==================== 初始化 ====================
  Future<void> init() async {
    anniversaries = await LocalStore.loadList(AppConfig.kAnniversaries);
    schedules = await LocalStore.loadList(AppConfig.kSchedules);
    periods = await LocalStore.loadList(AppConfig.kPeriods);
    moments = await LocalStore.loadList(AppConfig.kMoments);
    profiles = await LocalStore.loadList(AppConfig.kProfiles);

    nickname = await LocalStore.getString(AppConfig.kNickname) ?? '我';
    togetherSince = await LocalStore.getString(AppConfig.kTogetherSince) ?? '';

    myProfileId = await LocalStore.getString(AppConfig.kMyProfileId) ?? '';
    if (myProfileId.isEmpty) {
      myProfileId = genId();
      await LocalStore.setString(AppConfig.kMyProfileId, myProfileId);
    }
    myAvatar = await LocalStore.getString(AppConfig.kAvatar) ?? '';
    myRegId = await LocalStore.getString(AppConfig.kRegId) ?? '';

    final liked = await LocalStore.loadList(AppConfig.kLikedMomentIds);
    _likedMomentIds = liked.map((e) => e['id'].toString()).toSet();

    loading = false;
    notifyListeners();

    // 后台连接云端（不阻塞启动）
    unawaited(_initCloud());
  }

  Future<void> _initCloud() async {
    try {
      cloudAvailable = await CloudService.ping();
      if (cloudAvailable) {
        await pullFromCloud();
        await refreshMissYou();
        await refreshProfiles();
        syncMessage = '已同步';
      } else {
        syncMessage = '云端未连接，当前仅本地保存';
      }
    } catch (e) {
      cloudAvailable = false;
      syncMessage = '云端连接失败（$e）';
      debugPrint('云端初始化失败: $e');
    }
    await rescheduleNotifications();
    notifyListeners();
  }

  // ==================== 云端同步 ====================
  Future<void> pullFromCloud() async {
    if (!cloudAvailable) return;
    try {
      anniversaries = await _mergeTable(
        'anniversaries',
        anniversaries,
        AppConfig.kAnniversaries,
      );
      schedules = await _mergeTable(
        'schedules',
        schedules,
        AppConfig.kSchedules,
      );
      periods = await _mergeTable('periods', periods, AppConfig.kPeriods);
      moments = await _mergeTable('moments', moments, AppConfig.kMoments);
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('拉取云端失败: $e');
      syncMessage = '同步失败，使用本地数据';
    }
  }

  Future<void> refreshMissYou() async {
    if (!cloudAvailable) return;
    try {
      final rows = await CloudService.fetchAll('miss_you');
      rows.sort((a, b) {
        final ta = tryParseTime(a['created_at']) ?? DateTime(2000);
        final tb = tryParseTime(b['created_at']) ?? DateTime(2000);
        return tb.compareTo(ta);
      });
      missYouEvents = rows;
      notifyListeners();
    } catch (e) {
      debugPrint('拉取想你失败: $e');
    }
  }

  Future<void> refreshProfiles() async {
    if (!cloudAvailable) return;
    try {
      final rows = await CloudService.fetchAll('profiles');
      if (rows.isNotEmpty) {
        profiles = rows;
        await LocalStore.saveList(AppConfig.kProfiles, profiles);
        final mine = _myProfile();
        final url = mine?['avatar_url']?.toString() ?? '';
        if (url.isNotEmpty) {
          myAvatar = url;
          await LocalStore.setString(AppConfig.kAvatar, myAvatar);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('拉取头像失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _mergeTable(
    String table,
    List<Map<String, dynamic>> local,
    String localKey,
  ) async {
    try {
      final cloud = await CloudService.fetchAll(table);
      final cloudIds = cloud.map((e) => e['id']?.toString()).toSet();
      final toPush = local
          .where((e) => !cloudIds.contains(e['id']?.toString()))
          .toList();

      final merged = <String, Map<String, dynamic>>{};
      for (final e in local) {
        merged[e['id']?.toString() ?? ''] = e;
      }
      for (final e in cloud) {
        merged[e['id']?.toString() ?? ''] = e;
      }
      final result = merged.values.toList();

      for (final item in toPush) {
        try {
          await CloudService.insert(table, item);
        } catch (e) {
          debugPrint('补推 $table 失败: $e');
        }
      }
      await LocalStore.saveList(localKey, result);
      return result;
    } catch (e) {
      debugPrint('拉取 $table 失败: $e');
      return local;
    }
  }

  // ==================== 日历：纪念日 ====================
  Future<void> addAnniversary(String title, DateTime date) async {
    final item = {
      'id': genId(),
      'title': title,
      'date': fmtDate(date),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    anniversaries.add(item);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.insert('anniversaries', item));
  }

  Future<void> deleteAnniversary(String id) async {
    anniversaries.removeWhere((e) => e['id'] == id);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.delete('anniversaries', id));
  }

  // ==================== 日历：日程 ====================
  Future<void> addSchedule(
    String title,
    String time,
    DateTime date, {
    String endTime = '',
  }) async {
    final item = {
      'id': genId(),
      'title': title,
      'time': time,
      'end_time': endTime,
      'date': fmtDate(date),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    schedules.add(item);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.insert('schedules', item));
    unawaited(rescheduleNotifications());
  }

  Future<void> deleteSchedule(String id) async {
    schedules.removeWhere((e) => e['id'] == id);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.delete('schedules', id));
    unawaited(rescheduleNotifications());
  }

  /// 为所有未来日程安排本地到点通知
  Future<void> rescheduleNotifications() async {
    for (final id in _scheduledNotifIds) {
      await NotificationService.instance.cancel(id);
    }
    _scheduledNotifIds.clear();
    final now = DateTime.now();
    for (final s in schedules) {
      final when = _scheduleDateTime(s);
      if (when == null || !when.isAfter(now)) continue;
      final notifId = ('${s['id']}').hashCode & 0x7fffffff;
      _scheduledNotifIds.add(notifId);
      final time = s['time']?.toString() ?? '';
      final endTime = s['end_time']?.toString() ?? '';
      final label = endTime.isNotEmpty ? '$time-$endTime' : time;
      await NotificationService.instance.scheduleAt(
        id: notifId,
        title: '📅 日程提醒',
        body: '${s['title']}  $label',
        when: when,
      );
    }
  }

  DateTime? _scheduleDateTime(Map<String, dynamic> s) {
    try {
      final date = s['date']?.toString() ?? '';
      final time = s['time']?.toString() ?? '';
      if (date.isEmpty || time.isEmpty) return null;
      final parts = time.split(':');
      final h = int.tryParse(parts.first) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return parseDate(date).add(Duration(hours: h, minutes: m));
    } catch (_) {
      return null;
    }
  }

  // ==================== 日历：经期 ====================
  Future<void> addPeriod(DateTime start, int duration) async {
    final item = {
      'id': genId(),
      'start': fmtDate(start),
      'duration': duration,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    periods.add(item);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.insert('periods', item));
  }

  Future<void> deletePeriod(String id) async {
    periods.removeWhere((e) => e['id'] == id);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.delete('periods', id));
  }

  // ==================== 动态 ====================
  Future<void> addMoment(
    String content,
    List<String> images,
    String author,
  ) async {
    final item = {
      'id': genId(),
      'content': content,
      'images': images,
      'comments': <Map<String, dynamic>>[],
      'author': author,
      'author_avatar': myAvatar,
      'likes': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    moments.insert(0, item);
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.insert('moments', item));
  }

  Future<void> deleteMoment(String id) async {
    moments.removeWhere((e) => e['id'] == id);
    _likedMomentIds.remove(id);
    await _saveLikedIds();
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.delete('moments', id));
  }

  Future<void> toggleLike(String momentId) async {
    final idx = moments.indexWhere((e) => e['id'] == momentId);
    if (idx < 0) return;
    final moment = moments[idx];
    final likes = (moment['likes'] as num?)?.toInt() ?? 0;

    if (_likedMomentIds.contains(momentId)) {
      _likedMomentIds.remove(momentId);
      moment['likes'] = likes > 0 ? likes - 1 : 0;
    } else {
      _likedMomentIds.add(momentId);
      moment['likes'] = likes + 1;
    }
    await _saveLikedIds();
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.update('moments', momentId, {
          'likes': moment['likes'],
        }));
  }

  bool isLiked(String momentId) => _likedMomentIds.contains(momentId);

  Future<void> addComment(
    String momentId,
    String content,
    String author, {
    String? replyTo,
  }) async {
    final idx = moments.indexWhere((e) => e['id'] == momentId);
    if (idx < 0) return;
    final moment = moments[idx];
    final comments = (moment['comments'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    comments.add({
      'id': genId(),
      'content': content,
      'author': author,
      'reply_to': replyTo,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    moment['comments'] = comments;
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.update('moments', momentId, {
          'comments': comments,
        }));
  }

  Future<void> deleteComment(String momentId, String commentId) async {
    final idx = moments.indexWhere((e) => e['id'] == momentId);
    if (idx < 0) return;
    final moment = moments[idx];
    final comments = (moment['comments'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    comments.removeWhere((e) => e['id'] == commentId);
    moment['comments'] = comments;
    await _saveLocalAndNotify();
    _safeCloud(() => CloudService.update('moments', momentId, {
          'comments': comments,
        }));
  }

  /// 某位作者的头像（优先用动态里带的历史头像，其次按昵称查档案）
  String? avatarForMoment(Map<String, dynamic> moment) {
    final cached = moment['author_avatar']?.toString() ?? '';
    if (cached.isNotEmpty) return cached;
    return avatarFor(moment['author']?.toString() ?? '');
  }

  String? avatarFor(String nickname) {
    for (final p in profiles) {
      if ((p['nickname']?.toString() ?? '') == nickname) {
        final url = p['avatar_url']?.toString() ?? '';
        if (url.isNotEmpty) return url;
      }
    }
    return null;
  }

  Map<String, dynamic>? _myProfile() {
    for (final p in profiles) {
      if (p['id']?.toString() == myProfileId) return p;
    }
    return null;
  }

  /// 保存本机极光 registrationId（写入自己的档案，供对方定向推送）
  Future<void> setRegId(String regId) async {
    if (regId.isEmpty || regId == myRegId) return;
    myRegId = regId;
    await LocalStore.setString(AppConfig.kRegId, myRegId);
    await _upsertMyProfile();
    notifyListeners();
  }

  /// 对方设备的极光 registrationId
  String get partnerRegId {
    for (final p in profiles) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty && id != myProfileId) {
        final rid = p['jpush_reg_id']?.toString() ?? '';
        if (rid.isNotEmpty) return rid;
      }
    }
    return '';
  }

  /// 对方昵称
  String get partnerNickname {
    for (final p in profiles) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty && id != myProfileId) {
        final n = p['nickname']?.toString() ?? '';
        if (n.isNotEmpty) return n;
      }
    }
    return '';
  }

  Future<void> setAvatar(String url) async {
    myAvatar = url;
    await LocalStore.setString(AppConfig.kAvatar, myAvatar);
    await _upsertMyProfile();
    notifyListeners();
  }

  // ==================== "想你"互动 ====================
  Future<void> sendMissYou() async {
    final item = {
      'id': genId(),
      'author': nickname,
      'author_id': myProfileId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    missYouEvents.insert(0, item);
    notifyListeners();
    _pushMissYou(item);
    unawaited(PushService.instance.sendMissYou());
  }

  void onMissYouReceived() {
    missYouUnseenCount += 1;
    notifyListeners();
  }

  Future<void> clearMissYouUnseen() async {
    missYouUnseenCount = 0;
    notifyListeners();
  }

  // ==================== 设置 ====================
  Future<void> setNickname(String value) async {
    nickname = value.trim().isEmpty ? '我' : value.trim();
    await LocalStore.setString(AppConfig.kNickname, nickname);
    await _upsertMyProfile();
    notifyListeners();
  }

  Future<void> setTogetherSince(String dateStr) async {
    togetherSince = dateStr;
    await LocalStore.setString(AppConfig.kTogetherSince, togetherSince);
    notifyListeners();
  }

  int? get daysTogether {
    if (togetherSince.isEmpty) return null;
    final start = tryParseTime(togetherSince);
    if (start == null) return null;
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }

  int? get daysUntilNextAnniversary {
    if (togetherSince.isEmpty) return null;
    final start = tryParseTime(togetherSince);
    if (start == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, start.month, start.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, start.month, start.day);
    }
    final diff = DateTime(next.year, next.month, next.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return diff;
  }

  // ==================== 内部工具 ====================
  Future<void> _saveLocalAndNotify() async {
    await Future.wait([
      LocalStore.saveList(AppConfig.kAnniversaries, anniversaries),
      LocalStore.saveList(AppConfig.kSchedules, schedules),
      LocalStore.saveList(AppConfig.kPeriods, periods),
      LocalStore.saveList(AppConfig.kMoments, moments),
    ]);
    notifyListeners();
  }

  Future<void> _saveLikedIds() async {
    final list = _likedMomentIds.map((id) => {'id': id}).toList();
    await LocalStore.saveList(AppConfig.kLikedMomentIds, list);
  }

  Future<void> _upsertMyProfile() async {
    if (myProfileId.isEmpty) return;
    final row = {
      'id': myProfileId,
      'nickname': nickname,
      'avatar_url': myAvatar,
      'jpush_reg_id': myRegId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final idx = profiles.indexWhere((p) => p['id'] == myProfileId);
    if (idx >= 0) {
      profiles[idx] = row;
    } else {
      profiles.add(row);
    }
    await LocalStore.saveList(AppConfig.kProfiles, profiles);
    _safeCloud(() => CloudService.upsert('profiles', row));
  }

  void _pushMissYou(Map<String, dynamic> item) {
    _safeCloud(() => CloudService.insert('miss_you', item));
  }

  void _safeCloud(Future<void> Function() op) {
    unawaited(op().catchError((e) {
      debugPrint('云端同步失败（不影响本地）: $e');
    }));
  }

  @override
  void dispose() {
    pendingTab.dispose();
    super.dispose();
  }
}

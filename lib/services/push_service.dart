import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';

import '../app_config.dart';
import 'data_service.dart';
import 'notification_service.dart';

/// 极光推送服务：初始化、接收"想你"通知、发送"想你"推送。
///
/// 推送采用**按对方设备 registrationId 定向发送**（不用广播，避免极光广播限流）。
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final JPushFlutterInterface _jpush = JPush.newJPush();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    // 先注册事件，再 setup（插件文档要求）
    _jpush.addEventHandler(
      onReceiveNotification: (Map<String, dynamic> msg) async {
        _onForeground(msg);
      },
      onOpenNotification: (Map<String, dynamic> msg) async {
        // 点击通知：切到互动页
        DataService.instance.pendingTab.value = 2;
      },
    );
    _jpush.setup(
      appKey: AppConfig.jpushAppKey,
      channel: 'developer-default',
      production: false,
      debug: false,
    );
    try {
      _jpush.requestRequiredPermission(); // Android 13+ 通知权限
    } catch (_) {}
    // 拿设备 registrationId（存档案，供对方定向推送）
    unawaited(_registerDevice());
    // 标签作为兜底（拿不到对方 registrationId 时用）
    unawaited(_setTagWithRetry());
  }

  Future<void> _setTagWithRetry() async {
    for (var i = 0; i < 5; i++) {
      try {
        await _jpush.setTags([AppConfig.jpushTag]);
        return;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _registerDevice() async {
    for (var i = 0; i < 10; i++) {
      try {
        final rid = await _jpush.getRegistrationID();
        if (rid.isNotEmpty) {
          await DataService.instance.setRegId(rid);
          debugPrint('极光 registrationId: $rid');
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Map<String, dynamic> _extrasOf(Map<String, dynamic> msg) {
    final raw = msg['extras'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return {};
  }

  void _onForeground(Map<String, dynamic> msg) {
    final extras = _extrasOf(msg);
    if (extras['type'] != 'miss_you') return;

    final sender = extras['sender']?.toString() ?? '';
    final senderId = extras['sender_id']?.toString() ?? '';
    final myId = DataService.instance.myProfileId;

    // 区分是不是自己发的（优先用设备 ID，昵称作为兜底）
    final isMine = (senderId.isNotEmpty && senderId == myId) ||
        (senderId.isEmpty &&
            sender.isNotEmpty &&
            sender == DataService.instance.nickname);
    if (isMine) return;

    DataService.instance.onMissYouReceived();
    // 消息栏提醒（前台也弹，避免极光前台只回调不通知）
    unawaited(NotificationService.instance.showMissYou(sender));
    final ctx = AppConfig.navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💌 TA 想你了'),
        content: Text(
          sender.isEmpty
              ? '对方刚刚发来了一条想念，快去互动页看看吧～'
              : '「$sender」刚刚发来了一条想念，快去互动页看看吧～',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('收到 ❤️'),
          ),
        ],
      ),
    );
  }

  /// 给"对方设备"发一条"想你"推送（定向，不走广播）
  Future<void> sendMissYou() async {
    try {
      final auth = base64Encode(
        utf8.encode('${AppConfig.jpushAppKey}:${AppConfig.jpushMasterSecret}'),
      );

      final partnerRegId = DataService.instance.partnerRegId;
      final Map<String, dynamic> audience = partnerRegId.isNotEmpty
          ? {
              'registration_id': [partnerRegId],
            }
          : {
              'tag': [AppConfig.jpushTag],
            };

      final resp = await Dio().post(
        'https://api.jpush.cn/v3/push',
        options: Options(
          headers: {
            'Authorization': 'Basic $auth',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'platform': 'android',
          'audience': audience,
          'notification': {
            'alert': 'TA 想你了 ❤️',
            'android': {
              'alert': 'TA 想你了 ❤️',
              'title': 'Sweet Days',
              'extras': {
                'type': 'miss_you',
                'sender': DataService.instance.nickname,
                'sender_id': DataService.instance.myProfileId,
              },
            },
          },
        },
      );
      debugPrint('极光推送结果: ${resp.statusCode} ${resp.data}');
    } catch (e) {
      debugPrint('发送推送失败: $e');
    }
  }
}

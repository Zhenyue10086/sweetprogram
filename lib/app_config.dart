import 'package:flutter/material.dart';

import 'secrets.dart';

/// 全局配置：腾讯云开发 CloudBase + 极光推送 + 应用常量
///
/// ⚠️ 密钥都放在 `lib/secrets.dart`（已被 .gitignore 排除，不会上传 GitHub）。
/// 首次运行请复制 `lib/secrets.example.dart` 为 `lib/secrets.dart` 并填入自己的密钥。
class AppConfig {
  AppConfig._();

  // ===== 腾讯云开发 CloudBase =====
  static const String cloudbaseEnv = Secrets.cloudbaseEnv;
  static const String cloudbaseRegion = 'ap-shanghai';

  /// Publishable Key（匿名访问公钥）
  static const String publishableKey = Secrets.publishableKey;

  /// PostgREST 数据接口根地址（CloudBase PostgreSQL）
  static const String restBase =
      'https://${Secrets.cloudbaseEnv}.api.tcloudbasegateway.com/v1/rdb/rest';

  /// 云存储接口根地址 + 存储桶名
  static const String storageBase =
      'https://${Secrets.cloudbaseEnv}.api.tcloudbasegateway.com/v1/storages';
  static const String storageBucket = 'sweetdays';

  // ===== 极光推送 JPush =====
  static const String jpushAppKey = Secrets.jpushAppKey;
  static const String jpushMasterSecret = Secrets.jpushMasterSecret;

  /// 两台手机共用的推送标签（双方都加入）
  static const String jpushTag = 'sweet_couple';

  static const String appName = 'Sweet Days';

  /// 全局 NavigatorKey：任意位置弹窗 / 通知点击跳转
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ===== 本地存储 key（shared_preferences）=====
  static const String kAnniversaries = 'anniversaries';
  static const String kSchedules = 'schedules';
  static const String kPeriods = 'periods';
  static const String kMoments = 'moments';
  static const String kLikedMomentIds = 'liked_moment_ids';
  static const String kMissYouSeenAt = 'miss_you_seen_at';
  static const String kNickname = 'nickname';
  static const String kTogetherSince = 'together_since';
  static const String kMyProfileId = 'my_profile_id';
  static const String kAvatar = 'avatar_url';
  static const String kProfiles = 'profiles';
  static const String kRegId = 'jpush_reg_id';
}

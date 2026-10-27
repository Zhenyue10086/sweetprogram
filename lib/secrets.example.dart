/// 密钥模板文件（会入库）。
///
/// 使用方法：
/// 1. 复制本文件为 `secrets.dart`（与它在同一目录）；
/// 2. 填入你自己的腾讯云开发 CloudBase 与极光推送密钥；
/// 3. `secrets.dart` 已被 .gitignore 排除，不会上传。
class Secrets {
  static const String cloudbaseEnv = 'your-cloudbase-env-id';
  static const String publishableKey = 'your-cloudbase-publishable-key';
  static const String jpushAppKey = 'your-jpush-appkey';
  static const String jpushMasterSecret = 'your-jpush-master-secret';
}

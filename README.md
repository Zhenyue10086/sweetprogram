# Sweet Days · 恋爱纪念 App

一款送给女朋友的生日礼物 App —— 日历纪念日、日程与经期提醒、朋友圈式动态、以及「想你了」互动。

## ✨ 功能

- 📅 **日历**：纪念日 / 日程（自定义名称 + 开始/结束时间段，到点本地通知）/ 经期提醒；顶部带 **年 / 月 / 日** 三级选择器快速跳转
- 📷 **动态**：文字 + 多图（支持全屏查看、双指缩放、左右滑动）、点赞、评论回复、显示头像
- ❤️ **互动**：一键「想你了」（极光推送 + 本地消息栏通知）、自动计算在一起天数与周年倒计时
- 👤 **我的**：昵称、更换头像、在一起的日子、云端同步状态

## 🛠 技术栈

| 能力 | 方案 |
|------|------|
| 客户端 | Flutter (Dart) |
| 数据 | 腾讯云开发 CloudBase · PostgreSQL（PostgREST） |
| 图片 | CloudBase 云存储 |
| 推送 | 极光推送 JPush + 本地通知 flutter_local_notifications |
| 本地缓存 | shared_preferences（本地优先，断网可用） |

## 🚀 快速开始

1. `flutter pub get`
2. 复制 `lib/secrets.example.dart` 为 `lib/secrets.dart`，填入你自己的：
   - CloudBase 环境 ID / Publishable Key
   - 极光 AppKey / Master Secret
3. 在 CloudBase 的 SQL 编辑器依次执行：
   - `cloudbase_schema.sql`（建表 + 授权 + RLS）
   - `cloudbase_storage_policy.sql`（云存储 anon 读写）
   - `cloudbase_migration_v2.sql`（头像表 + 日程结束时间）
   - `cloudbase_migration_v3.sql`（设备推送 ID + 想你发送者 ID）
4. `flutter build apk --release`

## 🔒 安全说明

所有密钥都放在 `lib/secrets.dart`，该文件已被 `.gitignore` 排除，**不会上传到 GitHub**。
仓库里只保留 `lib/secrets.example.dart` 作为模板。

## 📄 文档

- [软件说明文档](软件说明文档.md)

import 'dart:math';

/// 通用工具函数：ID 生成、日期格式化、相对时间等

/// 生成一个简单的唯一 ID（微秒时间戳 + 随机数，避免两台设备同时生成撞车）
String genId() {
  final rand = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${DateTime.now().microsecondsSinceEpoch}_$rand';
}

/// 把 DateTime 格式化成 'yyyy-MM-dd'（本地和云端统一用这个格式存日期）
String fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 今天的 'yyyy-MM-dd'
String todayStr() => fmtDate(DateTime.now());

/// 把 'yyyy-MM-dd' 解析成 DateTime（不含时分秒）
DateTime parseDate(String s) => DateTime.parse(s);

/// 把时间显示成"刚刚 / 几分钟前 / 几小时前 / 几天前"，超过 7 天显示日期
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}

/// 安全地把一个字符串解析成 DateTime（解析失败返回 null）
DateTime? tryParseTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}

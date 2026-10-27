import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化层：把数据以 JSON 字符串的形式存进 shared_preferences。
///
/// 这样即使没有网络、没有云端，App 关闭重开后数据也不会丢。
class LocalStore {
  LocalStore._();

  /// 读取一个列表（存储的是 JSON 字符串）
  static Future<List<Map<String, dynamic>>> loadList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      // 数据损坏等情况，返回空列表，避免崩溃
      return [];
    }
  }

  /// 保存一个列表（整表覆盖写）
  static Future<void> saveList(String key, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  }

  /// 读取字符串
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// 保存字符串
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// 读取整数
  static Future<int?> getInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  /// 保存整数
  static Future<void> setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }
}

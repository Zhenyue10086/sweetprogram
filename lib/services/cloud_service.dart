import 'package:dio/dio.dart';

import '../app_config.dart';

/// 云端服务层：封装 CloudBase PostgreSQL 的 PostgREST 接口。
///
/// 和 Supabase 的 PostgREST 是同一套规范，只是路径前缀是 `/v1/rdb/rest`。
class CloudService {
  CloudService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Authorization': 'Bearer ${AppConfig.publishableKey}',
        'Content-Type': 'application/json',
      },
    ),
  );

  /// 查询整张表
  static Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    final resp = await _dio.get(
      '${AppConfig.restBase}/$table',
      queryParameters: {'select': '*', 'order': 'created_at'},
    );
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// 新增一行（id 由客户端生成并传入）
  static Future<void> insert(String table, Map<String, dynamic> row) async {
    await _dio.post(
      '${AppConfig.restBase}/$table',
      data: row,
      options: Options(headers: {'Prefer': 'return=representation'}),
    );
  }

  /// 按 id 更新
  static Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _dio.patch(
      '${AppConfig.restBase}/$table',
      data: data,
      queryParameters: {'id': 'eq.$id'},
    );
  }

  /// 按 id 删除
  static Future<void> delete(String table, String id) async {
    await _dio.delete(
      '${AppConfig.restBase}/$table',
      queryParameters: {'id': 'eq.$id'},
    );
  }

  /// 按 id upsert（存在则更新，不存在则插入）
  static Future<void> upsert(String table, Map<String, dynamic> row) async {
    await _dio.post(
      '${AppConfig.restBase}/$table',
      data: row,
      queryParameters: {'on_conflict': 'id'},
      options: Options(
        headers: {'Prefer': 'resolution=merge-duplicates,return=minimal'},
      ),
    );
  }

  /// 连通性测试（查纪念日表，成功即认为云端可用）
  static Future<bool> ping() async {
    try {
      await _dio.get(
        '${AppConfig.restBase}/anniversaries',
        queryParameters: {'select': 'id', 'limit': 1},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

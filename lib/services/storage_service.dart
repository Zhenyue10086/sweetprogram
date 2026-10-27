import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../app_config.dart';

/// 图片存储：CloudBase PG 云存储（显式指定存储桶 `sweetdays`）。
///
/// 流程：上传（二进制直传）→ 换取预签名下载链接 → 返回可长期访问的 URL。
class StorageService {
  StorageService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Authorization': 'Bearer ${AppConfig.publishableKey}'},
    ),
  );

  /// 上传图片字节，返回可长期访问的签名 URL
  static Future<String> upload(Uint8List bytes, {String ext = 'jpg'}) async {
    // 用扁平 key（避免路径里的 / 影响路由）
    final key = 'moment_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final url = '${AppConfig.storageBase}/object/${AppConfig.storageBucket}/$key';

    // 1. 上传（二进制 body 直传）
    await _dio.post(
      url,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    // 2. 换取长期签名下载链接（10 年有效）
    final signResp = await _dio.post(
      '${AppConfig.storageBase}/object/sign/${AppConfig.storageBucket}/$key',
      data: {'expiresIn': 315360000},
      options: Options(contentType: 'application/json'),
    );

    final data = signResp.data;
    if (data is Map) {
      final full = data['fullSignedURL'] ?? data['signedURL'];
      if (full != null && full.toString().isNotEmpty) {
        return full.toString();
      }
    }
    throw Exception('获取图片链接失败');
  }
}

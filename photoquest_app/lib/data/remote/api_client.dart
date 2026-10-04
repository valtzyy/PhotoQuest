import 'package:dio/dio.dart';

import '../../core/config.dart';

/// Klien HTTP tunggal untuk backend PhotoQuest.
///
/// Fase 1: hanya base URL + timeout 8 detik.
/// Fase 2: ditambah interceptor JWT (header Authorization) dan auto-logout saat 401.
class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.requestTimeout,
            receiveTimeout: AppConfig.requestTimeout,
            sendTimeout: AppConfig.requestTimeout,
            contentType: 'application/json',
          ),
        );

  final Dio dio;

  /// Cek koneksi ke backend: GET /health.
  /// Mengembalikan `data` dari format respons `{ success, data, message }`.
  Future<Map<String, dynamic>> health() async {
    final res = await dio.get('/health');
    final body = res.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }
}

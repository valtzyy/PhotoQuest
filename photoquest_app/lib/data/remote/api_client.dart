import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../local/secure_store.dart';
import 'api_exception.dart';

/// Klien HTTP tunggal untuk backend PhotoQuest.
///
/// - Timeout 8 detik untuk semua request.
/// - Interceptor menambahkan header `Authorization: Bearer <JWT>` otomatis.
/// - Interceptor memanggil [onUnauthorized] bila server membalas 401
///   (token kedaluwarsa/tidak valid) -> aplikasi logout otomatis.
class ApiClient {
  ApiClient(this._store)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.requestTimeout,
            receiveTimeout: AppConfig.requestTimeout,
            sendTimeout: AppConfig.requestTimeout,
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final path = error.requestOptions.path;
          // 401 dari login/register berarti "password salah", bukan session habis.
          final isCredentialEndpoint =
              path.startsWith('/auth/login') || path.startsWith('/auth/register');
          if (error.response?.statusCode == 401 && !isCredentialEndpoint) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final SecureStore _store;
  final Dio dio;

  /// Diisi oleh AuthProvider: aksi logout otomatis saat respons 401.
  void Function()? onUnauthorized;

  /// Helper: jalankan request dan kembalikan field `data` dari
  /// `{ success, data, message }`. Semua DioException diubah jadi [ApiException].
  Future<T> send<T>(Future<Response<dynamic>> Function(Dio dio) request) async {
    try {
      final res = await request(dio);
      return (res.data as Map<String, dynamic>)['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

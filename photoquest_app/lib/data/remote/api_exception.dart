import 'package:dio/dio.dart';

/// Error API yang sudah diterjemahkan menjadi pesan bahasa Indonesia.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  final String message;
  final int? statusCode;

  /// true jika server tidak bisa dihubungi (timeout / tidak ada koneksi).
  /// Dipakai untuk memutuskan fallback ke cache lokal ("Mode offline").
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Server tidak merespons (timeout 8 detik)',
            isNetworkError: true);
      case DioExceptionType.connectionError:
        return const ApiException('Tidak dapat terhubung ke server',
            isNetworkError: true);
      default:
        break;
    }
    // Backend selalu membalas { success, data, message } -> ambil message-nya.
    final data = e.response?.data;
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Terjadi kesalahan (${e.response?.statusCode ?? 'tanpa respons'})';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}

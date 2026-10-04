import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/data/remote/api_exception.dart';

void main() {
  final req = RequestOptions(path: '/auth/me');

  test('Timeout -> isNetworkError (memicu fallback offline)', () {
    final e = ApiException.fromDio(
        DioException(requestOptions: req, type: DioExceptionType.connectionTimeout));
    expect(e.isNetworkError, isTrue);
    expect(e.isUnauthorized, isFalse);
  });

  test('401 -> isUnauthorized dengan pesan dari backend', () {
    final e = ApiException.fromDio(DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: req,
        statusCode: 401,
        data: {'success': false, 'data': null, 'message': 'Token tidak valid'},
      ),
    ));
    expect(e.isUnauthorized, isTrue);
    expect(e.isNetworkError, isFalse);
    expect(e.message, 'Token tidak valid');
  });
}

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Endpoint profil: /users/*
class UserApi {
  UserApi(this._client);
  final ApiClient _client;

  Future<User> updateName(String name) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.put('/users/me', data: {'name': name}),
    );
    return User.fromJson(data);
  }

  /// Upload foto profil sebagai multipart/form-data (field "photo").
  Future<User> uploadPhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        filePath,
        filename: p.basename(filePath),
        // Tanpa ini dio mengirim application/octet-stream dan ditolak backend.
        contentType: _mediaTypeFor(filePath),
      ),
    });
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post('/users/me/photo', data: form),
    );
    return User.fromJson(data);
  }

  /// Mengambil biner foto profil (endpoint butuh JWT, jadi tidak memakai Image.network).
  Future<Uint8List> fetchPhoto(String photoUrl) async {
    try {
      final res = await _client.dio.get<List<int>>(
        photoUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  DioMediaType _mediaTypeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return DioMediaType('image', 'png');
      case '.webp':
        return DioMediaType('image', 'webp');
      default:
        return DioMediaType('image', 'jpeg');
    }
  }
}

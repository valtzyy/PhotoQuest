import '../models/user.dart';
import 'api_client.dart';

/// Hasil login/register: JWT + data user.
class AuthResult {
  const AuthResult(this.token, this.user);
  final String token;
  final User user;
}

/// Pemanggil endpoint /auth/* di backend.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<AuthResult> login(String email, String password) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) =>
          dio.post('/auth/login', data: {'email': email, 'password': password}),
    );
    return _toResult(data);
  }

  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      ),
    );
    return _toResult(data);
  }

  /// Validasi token yang tersimpan dan ambil data user terbaru.
  Future<User> me() async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.get('/auth/me'),
    );
    return User.fromJson(data);
  }

  AuthResult _toResult(Map<String, dynamic> data) => AuthResult(
    data['token'] as String,
    User.fromJson(data['user'] as Map<String, dynamic>),
  );
}

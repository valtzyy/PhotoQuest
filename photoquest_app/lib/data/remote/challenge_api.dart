import 'api_client.dart';

/// Endpoint Steady Shot Challenge: /challenge
/// (Fase 3: riwayat saja; kirim hasil challenge ditambahkan di Fase 10.)
class ChallengeApi {
  ChallengeApi(this._client);
  final ApiClient _client;

  Future<List<dynamic>> historyRaw() =>
      _client.send<List<dynamic>>((dio) => dio.get('/challenge'));
}

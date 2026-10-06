import '../models/chain_block.dart';
import 'api_client.dart';

/// Hasil POST /challenge.
class ChallengeSubmitResult {
  const ChallengeSubmitResult({this.blockIndex, this.blockHash});

  /// Nomor blok di blockchain (null jika challenge gagal / tidak dicatat).
  final int? blockIndex;
  final String? blockHash;
}

/// Endpoint Steady Shot Challenge (/challenge) dan Chain Explorer (/chain).
class ChallengeApi {
  ChallengeApi(this._client);
  final ApiClient _client;

  Future<List<dynamic>> historyRaw() =>
      _client.send<List<dynamic>>((dio) => dio.get('/challenge'));

  Future<ChallengeSubmitResult> submit({
    required bool success,
    required double holdSeconds,
    required double avgTilt,
    required double avgShake,
  }) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post(
        '/challenge',
        data: {
          'success': success,
          'hold_seconds': holdSeconds,
          'avg_tilt': avgTilt,
          'avg_shake': avgShake,
        },
      ),
    );
    final block = data['block'] as Map<String, dynamic>?;
    return ChallengeSubmitResult(
      blockIndex: block?['block_index'] as int?,
      blockHash: block?['hash'] as String?,
    );
  }

  Future<ChainInfo> chain() async => ChainInfo.fromJson(
    await _client.send<Map<String, dynamic>>((dio) => dio.get('/chain')),
  );

  Future<ChainVerification> verify() async => ChainVerification.fromJson(
    await _client.send<Map<String, dynamic>>((dio) => dio.get('/chain/verify')),
  );

  Future<void> tamperDemo() =>
      _client.send<dynamic>((dio) => dio.post('/chain/tamper-demo'));

  Future<void> repairDemo() =>
      _client.send<dynamic>((dio) => dio.post('/chain/repair-demo'));
}

import '../models/chain_record.dart';
import 'api_client.dart';

/// Hasil POST /challenge.
class ChallengeSubmitResult {
  const ChallengeSubmitResult({this.chainStatus});

  /// Status pencatatan blockchain: null bila challenge gagal / tidak dicatat,
  /// pending bila transaksi Sepolia sedang diproses di latar belakang.
  final ChainStatus? chainStatus;
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
    final chain = data['chain'] as Map<String, dynamic>?;
    return ChallengeSubmitResult(
      chainStatus: chain == null
          ? null
          : ChainStatus.parse(chain['status'] as String?),
    );
  }

  Future<ChainInfo> chain() async => ChainInfo.fromJson(
    await _client.send<Map<String, dynamic>>((dio) => dio.get('/chain')),
  );

  Future<ChainVerification> verify() async => ChainVerification.fromJson(
    await _client.send<Map<String, dynamic>>((dio) => dio.get('/chain/verify')),
  );

  /// Kirim ulang catatan yang gagal ke Sepolia; mengembalikan jumlah yang diantrikan.
  Future<int> retry() async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post('/chain/retry'),
    );
    return data['queued'] as int? ?? 0;
  }

  Future<void> tamperDemo() =>
      _client.send<dynamic>((dio) => dio.post('/chain/tamper-demo'));

  Future<void> repairDemo() =>
      _client.send<dynamic>((dio) => dio.post('/chain/repair-demo'));
}

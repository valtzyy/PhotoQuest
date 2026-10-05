import 'package:dio/dio.dart';

import '../models/score_result.dart';
import 'api_client.dart';

/// Satu pesan chat (riwayat hanya disimpan di memori aplikasi).
class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  /// 'user' | 'assistant'
  final String role;
  final String text;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// Endpoint AI: skor kondisi, rekomendasi, chat assistant, dan sesi foto.
class AiApi {
  AiApi(this._client);
  final ApiClient _client;

  /// Server memanggil cuaca (≤ 8 dtk) lalu LLM (≤ 8 dtk), jadi aplikasi
  /// menunggu lebih lama khusus untuk endpoint AI.
  static final _aiOptions = Options(
    receiveTimeout: const Duration(seconds: 20),
  );

  Future<ScoreResult> score({
    required int spotId,
    required String photoType,
    required DateTime plannedAt,
    int? cloudCover,
    int? rainProb,
  }) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post(
        '/ai/score',
        data: {
          'spot_id': spotId,
          'photo_type': photoType,
          'planned_at': plannedAt.toUtc().toIso8601String(),
          'cloud_cover': ?cloudCover,
          'rain_prob': ?rainProb,
        },
        options: _aiOptions,
      ),
    );
    return ScoreResult.fromJson(data);
  }

  /// Kirim pesan ke Photography Assistant beserta konteks & riwayat singkat.
  Future<String> chat({
    required String message,
    int? spotId,
    Map<String, String>? context,
    List<ChatMessage> history = const [],
  }) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post(
        '/ai/chat',
        data: {
          'message': message,
          'spot_id': ?spotId,
          'context': ?context,
          // Hanya 10 pesan terakhir agar prompt tetap pendek.
          'history': history
              .skip(history.length > 10 ? history.length - 10 : 0)
              .map((m) => m.toJson())
              .toList(),
        },
        options: _aiOptions,
      ),
    );
    return data['reply'] as String;
  }

  Future<void> saveSession({
    required int spotId,
    required String photoType,
    required DateTime plannedAt,
    required int score,
    required Recommendation recommendation,
  }) => _client.send<dynamic>(
    (dio) => dio.post(
      '/sessions',
      data: {
        'spot_id': spotId,
        'photo_type': photoType,
        'planned_at': plannedAt.toUtc().toIso8601String(),
        'score': score,
        'recommendation': recommendation.toJson(),
      },
    ),
  );

  Future<List<PhotoSession>> sessions() async {
    final data = await _client.send<List<dynamic>>(
      (dio) => dio.get('/sessions'),
    );
    return data
        .map((e) => PhotoSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

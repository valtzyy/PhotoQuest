import '../models/feedback_item.dart';
import 'api_client.dart';

/// Endpoint Saran & Kesan: /feedback
class FeedbackApi {
  FeedbackApi(this._client);
  final ApiClient _client;

  Future<FeedbackItem> send(String saran, String kesan) async {
    final data = await _client.send<Map<String, dynamic>>(
      (dio) => dio.post('/feedback', data: {'saran': saran, 'kesan': kesan}),
    );
    return FeedbackItem.fromJson(data);
  }

  /// Mengembalikan JSON mentah agar bisa langsung disimpan ke cache.
  Future<List<dynamic>> mineRaw() =>
      _client.send<List<dynamic>>((dio) => dio.get('/feedback/me'));
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/local/weather_dao.dart';
import 'package:photoquest_app/data/models/score_result.dart';
import 'package:photoquest_app/data/models/spot.dart';
import 'package:photoquest_app/data/models/weather_info.dart';
import 'package:photoquest_app/data/remote/ai_api.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/api_exception.dart';
import 'package:photoquest_app/data/remote/weather_api.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/weather_repository.dart';
import 'package:photoquest_app/providers/weather_provider.dart';
import 'package:photoquest_app/ui/screens/assistant_screen.dart';
import 'package:photoquest_app/ui/screens/plan_screen.dart';

final _client = ApiClient(SecureStore());

const _spot = Spot(
  id: 14,
  name: 'Tebing Breksi',
  category: 'landscape',
  description: 'Tebing',
  latitude: -7.782,
  longitude: 110.5048,
  bestTime: 'sunset',
  photoTypes: ['landscape', 'sunset'],
);

Map<String, dynamic> scoreJson({String source = 'template'}) => {
  'score': 86,
  'label': 'Sangat Baik',
  'breakdown': [
    {
      'key': 'timing',
      'label': 'Timing cahaya',
      'score': 40,
      'max': 40,
      'note': 'Tepat di golden hour sore',
    },
    {
      'key': 'cloud',
      'label': 'Tutupan awan',
      'score': 30,
      'max': 30,
      'note': 'Tutupan awan 40%',
    },
    {
      'key': 'rain',
      'label': 'Peluang hujan',
      'score': 16,
      'max': 20,
      'note': 'Peluang hujan 20%',
    },
    {
      'key': 'spot',
      'label': 'Kecocokan spot',
      'score': 0,
      'max': 10,
      'note': '-',
    },
  ],
  'conditions': {
    'cloud_cover': 40,
    'rain_prob': 20,
    'source': 'forecast',
    'weather_source': 'live',
  },
  'golden_hour': {
    'morning': {
      'start': '2026-10-06T22:21:00.000Z',
      'end': '2026-10-06T23:21:00.000Z',
    },
    'evening': {
      'start': '2026-10-07T09:32:00.000Z',
      'end': '2026-10-07T10:32:00.000Z',
    },
  },
  'recommendation': {
    'composition': ['Rule of thirds', 'Foreground batu'],
    'timing': 'Datang 16.00',
    'position': 'Menghadap barat',
    'stability': 'Pakai tripod',
    'tips': ['Turunkan eksposur'],
  },
  'recommendation_source': source,
};

/// AiApi palsu: mencatat panggilan, tanpa jaringan.
class _FakeAi extends AiApi {
  _FakeAi() : super(_client);

  Map<String, dynamic>? lastScoreArgs;
  int savedSessions = 0;
  bool chatFails = false;
  Map<String, String>? lastChatContext;
  List<ChatMessage>? lastHistory;

  @override
  Future<ScoreResult> score({
    required int spotId,
    required String photoType,
    required DateTime plannedAt,
    int? cloudCover,
    int? rainProb,
  }) async {
    lastScoreArgs = {
      'spotId': spotId,
      'photoType': photoType,
      'cloud': cloudCover,
      'rain': rainProb,
    };
    return ScoreResult.fromJson(scoreJson());
  }

  @override
  Future<void> saveSession({
    required int spotId,
    required String photoType,
    required DateTime plannedAt,
    required int score,
    required Recommendation recommendation,
  }) async => savedSessions++;

  @override
  Future<String> chat({
    required String message,
    int? spotId,
    Map<String, String>? context,
    List<ChatMessage> history = const [],
  }) async {
    lastChatContext = context;
    lastHistory = history;
    if (chatFails) {
      throw const ApiException(
        'Assistant sedang tidak tersedia, coba lagi',
        statusCode: 503,
      );
    }
    return 'Gunakan rule of thirds.';
  }
}

class _FakeWeatherRepo extends WeatherRepository {
  _FakeWeatherRepo()
    : super(WeatherApi(_client), WeatherDao(DbHelper.instance));

  @override
  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async =>
      CachedResult(WeatherInfo.estimate(DateTime.now()));
}

Widget _wrap(Widget child, AiApi ai) => MultiProvider(
  providers: [
    Provider<AiApi>.value(value: ai),
    ChangeNotifierProvider(create: (_) => WeatherProvider(_FakeWeatherRepo())),
  ],
  child: MaterialApp(home: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test(
    'ScoreResult.fromJson membaca skor, rincian, kondisi, & rekomendasi',
    () {
      final r = ScoreResult.fromJson(scoreJson(source: 'ai'));
      expect(r.score, 86);
      expect(r.breakdown.map((b) => b.max), [40, 30, 20, 10]);
      expect(r.conditionSource, 'forecast');
      expect(r.isAi, isTrue);
      expect(r.recommendation.composition, hasLength(2));
    },
  );

  testWidgets(
    'Plan: Analisis -> gauge, rincian, rekomendasi template, simpan sesi',
    (tester) async {
      final ai = _FakeAi();
      await tester.pumpWidget(_wrap(const PlanScreen(initialSpot: _spot), ai));
      await tester.pumpAndSettle();

      // Pilih cuaca manual "Hujan" -> dikirim sebagai awan 95% / hujan 85%
      await tester.tap(find.text('Hujan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();
      expect(ai.lastScoreArgs, {
        'spotId': 14,
        'photoType': 'landscape',
        'cloud': 95,
        'rain': 85,
      });
      // Hasil ada di bawah form -> gulir dulu (ListView hanya membangun yang terlihat).
      await tester.scrollUntilVisible(find.text('86'), 200);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('Sangat Baik'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Template'), 200);
      expect(find.text('Template'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Simpan Sesi'), 200);
      await tester.tap(find.text('Simpan Sesi'));
      await tester.pumpAndSettle();
      expect(ai.savedSessions, 1);
      expect(find.text('Tersimpan'), findsOneWidget);
    },
  );

  testWidgets('Assistant: chip konteks, kirim pesan, dan riwayat', (
    tester,
  ) async {
    final ai = _FakeAi();
    await tester.pumpWidget(
      _wrap(
        const AssistantScreen(
          spot: _spot,
          planContext: {'score': '86', 'label': 'Sangat Baik'},
        ),
        ai,
      ),
    );
    expect(find.text('Tebing Breksi'), findsOneWidget); // chip konteks
    expect(find.text('Skor 86 (Sangat Baik)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tips sunset?');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pumpAndSettle();
    expect(find.text('Gunakan rule of thirds.'), findsOneWidget);
    expect(ai.lastChatContext, {'score': '86', 'label': 'Sangat Baik'});

    await tester.enterText(find.byType(TextField), 'Lalu?');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pumpAndSettle();
    // Riwayat yang dikirim = 2 pesan sebelumnya (user + assistant)
    expect(ai.lastHistory!.map((m) => m.role), ['user', 'assistant']);
  });

  testWidgets('Assistant gagal -> pesan "tidak tersedia" + tombol coba lagi', (
    tester,
  ) async {
    final ai = _FakeAi()..chatFails = true;
    await tester.pumpWidget(_wrap(const AssistantScreen(), ai));

    await tester.enterText(find.byType(TextField), 'Halo');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pumpAndSettle();
    expect(
      find.text('Assistant sedang tidak tersedia, coba lagi'),
      findsWidgets,
    );

    ai.chatFails = false;
    await tester.tap(
      find.widgetWithText(
        TextButton,
        'Assistant sedang tidak tersedia, coba lagi',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gunakan rule of thirds.'), findsOneWidget);
  });
}

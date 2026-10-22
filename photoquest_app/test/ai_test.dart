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
import 'package:photoquest_app/ui/widgets/markdown_text.dart';

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
  bool? lastFromForecast;
  int savedSessions = 0;
  bool chatFails = false;
  String chatReply = 'Gunakan rule of thirds.';
  Map<String, String>? lastChatContext;
  List<ChatMessage>? lastHistory;

  @override
  Future<ScoreResult> score({
    required int spotId,
    required String photoType,
    required DateTime plannedAt,
    int? cloudCover,
    int? rainProb,
    bool fromForecast = false,
  }) async {
    lastFromForecast = fromForecast;
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
    return chatReply;
  }
}

class _FakeWeatherRepo extends WeatherRepository {
  _FakeWeatherRepo({this.result})
    : super(WeatherApi(_client), WeatherDao(DbHelper.instance));

  final CachedResult<WeatherInfo>? result;

  @override
  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async =>
      result ?? CachedResult(WeatherInfo.estimate(DateTime.now()));
}

/// Prakiraan live: awan 70% / hujan 30% pada jam-jam sekitar sekarang.
WeatherInfo _liveInfo() {
  final now = DateTime.now();
  return WeatherInfo.fromJson({
    'source': 'live',
    'is_estimate': false,
    'fetched_at': now.toUtc().toIso8601String(),
    'current': null,
    'days': [],
    'hourly': [
      for (var h = 0; h < 4; h++)
        {
          'time': now.add(Duration(hours: h)).toUtc().toIso8601String(),
          'cloud_cover': 70,
          'precipitation_probability': 30,
        },
    ],
  });
}

Widget _wrap(Widget child, AiApi ai, {CachedResult<WeatherInfo>? weather}) =>
    MultiProvider(
      providers: [
        Provider<AiApi>.value(value: ai),
        ChangeNotifierProvider(
          create: (_) => WeatherProvider(_FakeWeatherRepo(result: weather)),
        ),
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

  testWidgets(
    'Plan Otomatis + prakiraan live di HP -> dikirim ke AI sebagai from_forecast',
    (tester) async {
      final ai = _FakeAi();
      await tester.pumpWidget(
        _wrap(
          const PlanScreen(initialSpot: _spot),
          ai,
          weather: CachedResult(_liveInfo()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();
      expect(ai.lastScoreArgs!['cloud'], 70);
      expect(ai.lastScoreArgs!['rain'], 30);
      expect(ai.lastFromForecast, isTrue);
    },
  );

  testWidgets(
    'Plan Otomatis tanpa data cuaca di HP (estimasi) -> server yang menentukan',
    (tester) async {
      final ai = _FakeAi();
      await tester.pumpWidget(_wrap(const PlanScreen(initialSpot: _spot), ai));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();
      expect(ai.lastScoreArgs!['cloud'], isNull);
      expect(ai.lastScoreArgs!['rain'], isNull);
      expect(ai.lastFromForecast, isFalse);
    },
  );

  testWidgets('Plan Otomatis dengan data lama dari cache HP -> tidak dikirim', (
    tester,
  ) async {
    final ai = _FakeAi();
    await tester.pumpWidget(
      _wrap(
        const PlanScreen(initialSpot: _spot),
        ai,
        weather: CachedResult(_liveInfo(), cachedAt: DateTime(2026, 10, 1)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analisis'));
    await tester.pumpAndSettle();
    expect(ai.lastScoreArgs!['cloud'], isNull);
    expect(ai.lastFromForecast, isFalse);
  });

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
    expect(
      find.text('Gunakan rule of thirds.', findRichText: true),
      findsOneWidget,
    );
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
    expect(
      find.text('Gunakan rule of thirds.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Assistant: markdown jawaban dirender tanpa tanda bintang', (
    tester,
  ) async {
    final ai = _FakeAi()
      ..chatReply =
          '**Siluet** saat *sunset*:\n* Ukur cahaya ke langit\n1. Pakai **f/8**';
    await tester.pumpWidget(_wrap(const AssistantScreen(), ai));

    await tester.enterText(find.byType(TextField), 'Siluet **x**?');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pumpAndSettle();

    // Pesan pengguna tetap teks biasa (bintang tidak diolah).
    expect(find.text('Siluet **x**?'), findsOneWidget);
    expect(
      find.text('Siluet saat sunset:', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Ukur cahaya ke langit', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('•'), findsOneWidget);
    expect(find.text('Pakai f/8', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsOneWidget);
  });

  test('MarkdownText.inlineSpans: tebal, miring, dan teks biasa', () {
    final spans = MarkdownText.inlineSpans('a **b** *c* 2 * 3', Colors.black);
    expect(spans.map((s) => s.text), ['a ', 'b', ' ', 'c', ' 2 * 3']);
    expect(spans[1].style!.fontWeight, FontWeight.w700);
    expect(spans[3].style!.fontStyle, FontStyle.italic);
  });
}

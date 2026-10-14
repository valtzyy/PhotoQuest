import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/core/pq_colors.dart';
import 'package:photoquest_app/core/theme.dart';
import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/json_cache.dart';
import 'package:photoquest_app/data/local/quiz_dao.dart';
import 'package:photoquest_app/data/models/quiz_question.dart';
import 'package:photoquest_app/providers/theme_mode_provider.dart';
import 'package:photoquest_app/ui/screens/profile_screen.dart';
import 'package:photoquest_app/ui/screens/quiz_screen.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/local/weather_dao.dart';
import 'package:photoquest_app/data/models/challenge_attempt.dart';
import 'package:photoquest_app/data/models/feedback_item.dart';
import 'package:photoquest_app/data/models/spot.dart';
import 'package:photoquest_app/data/models/weather_info.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/data/remote/feedback_api.dart';
import 'package:photoquest_app/data/remote/user_api.dart';
import 'package:photoquest_app/data/remote/weather_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/feedback_repository.dart';
import 'package:photoquest_app/data/repositories/profile_repository.dart';
import 'package:photoquest_app/data/repositories/weather_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/providers/location_provider.dart';
import 'package:photoquest_app/providers/weather_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';
import 'package:photoquest_app/services/location_service.dart';
import 'package:photoquest_app/ui/screens/login_screen.dart';
import 'package:photoquest_app/ui/screens/main_shell.dart';
import 'package:photoquest_app/ui/widgets/spot_card.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_icon_tile.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_panel.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_pill.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_pressable.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_progress_bar.dart';
import 'package:photoquest_app/ui/widgets/glass/holo_card_frame.dart';
import 'package:photoquest_app/ui/widgets/glass/pq_background.dart';

/// Jalankan:
/// flutter test test/ui_preview_test.dart --update-goldens --dart-define=PQ_PREVIEW=true
/// Hasil: test/preview/gallery_light.png dan gallery_dark.png (di-gitignore).
const _enabled = bool.fromEnvironment('PQ_PREVIEW');

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Galeri komponen')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Row(
              children: [
                GlassPill(label: 'Soal 3 dari 10 · Skor 2'),
                Spacer(),
                GlassPill(label: 'Level 4', tone: GlassTone.blue),
              ],
            ),
            const SizedBox(height: 12),
            const GlassProgressBar(value: 0.3),
            const SizedBox(height: 16),
            Text('Halo, Si-ID', style: theme.textTheme.titleLarge),
            const Text('Siap berburu cahaya hari ini?'),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 10,
              children: [
                GlassIconTile(icon: Icons.explore, colors: PqPalette.tileRed),
                GlassIconTile(icon: Icons.map, colors: PqPalette.tileBlue),
                GlassIconTile(icon: Icons.quiz, colors: PqPalette.tileYellow),
                GlassIconTile(
                  icon: Icons.insights,
                  colors: PqPalette.tilePurple,
                ),
                GlassIconTile(
                  icon: Icons.currency_exchange,
                  colors: PqPalette.tileGreen,
                ),
                GlassIconTile(
                  icon: Icons.sports_esports,
                  colors: PqPalette.tileOrange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () {}, child: const Text('Masuk')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('Ulangi')),
            const SizedBox(height: 12),
            const FilledButton(onPressed: null, child: Text('Nonaktif')),
            TextButton(
              onPressed: () {},
              child: const Text('Belum punya akun? Daftar'),
            ),
            const SizedBox(height: 8),
            for (final tone in [
              GlassTone.yellow,
              GlassTone.green,
              GlassTone.red,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPressable(
                  tone: tone,
                  onTap: () {},
                  child: Text('Jawaban ${tone.name}'),
                ),
              ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle),
                title: Text('Benar!'),
                subtitle: Text('Noise berkurang saat ISO diturunkan.'),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Jalanan'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            HoloCardFrame(
              onTap: () {},
              child: Text('Bukit Sikunir', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 16),
            const GlassPanel(blur: true, child: Text('Panel frosted (blur)')),
          ],
        ),
      ),
    );
  }
}

// ---- Data palsu untuk pratinjau layar (tanpa jaringan/sqflite) ----
final _client = ApiClient(SecureStore());

class _FakeProfileRepo extends ProfileRepository {
  _FakeProfileRepo()
    : super(
        UserApi(_client),
        ChallengeApi(_client),
        JsonCache(DbHelper.instance),
      );

  @override
  Future<CachedResult<List<ChallengeAttempt>>> challengeHistory() async =>
      const CachedResult(<ChallengeAttempt>[]);
}

class _FakeFeedbackRepo extends FeedbackRepository {
  _FakeFeedbackRepo()
    : super(FeedbackApi(_client), JsonCache(DbHelper.instance));

  @override
  Future<CachedResult<List<FeedbackItem>>> getMine() async =>
      const CachedResult(<FeedbackItem>[]);
}

class _FakeLocation extends LocationProvider {
  _FakeLocation() : super(LocationService(), DbHelper.instance);

  @override
  Future<void> init() async {}
}

class _FakeWeatherRepo extends WeatherRepository {
  _FakeWeatherRepo()
    : super(WeatherApi(_client), WeatherDao(DbHelper.instance));

  @override
  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async =>
      CachedResult(WeatherInfo.estimate(DateTime.now()));
}

Widget _withFakes(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => AuthProvider(
        AuthRepository(AuthApi(_client), SecureStore(), DbHelper.instance),
        BiometricService(),
        _client,
      ),
    ),
    Provider<ProfileRepository>.value(value: _FakeProfileRepo()),
    Provider<FeedbackRepository>.value(value: _FakeFeedbackRepo()),
    ChangeNotifierProvider<LocationProvider>.value(value: _FakeLocation()),
    ChangeNotifierProvider<WeatherProvider>.value(
      value: WeatherProvider(_FakeWeatherRepo()),
    ),
    Provider<QuizDao>.value(value: _FakeQuizDao()),
  ],
  child: child,
);

class _FakeQuizDao extends QuizDao {
  _FakeQuizDao() : super(DbHelper.instance);

  @override
  Future<List<QuizQuestion>> randomQuestions({int count = 10}) async =>
      quizSeed.take(2).toList();
}

Spot _spot(int id, String name, String category) => Spot(
  id: id,
  name: name,
  category: category,
  description: 'Deskripsi $name',
  latitude: -7.8,
  longitude: 110.36,
  bestTime: 'sunset',
  photoTypes: const ['landscape', 'sunset'],
);

class _SpotList extends StatelessWidget {
  const _SpotList();

  @override
  Widget build(BuildContext context) {
    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Explore Spot')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, s) in [
              _spot(1, 'Candi Prambanan', 'culture'),
              _spot(2, 'Pantai Parangtritis', 'landscape'),
              _spot(3, 'Jalan Malioboro', 'street'),
              _spot(4, 'Hutan Pinus Mangunan', 'nature'),
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SpotCard(
                  spot: s,
                  isFavorite: i == 1,
                  distanceKm: 2.4 + i * 3.1,
                  onTap: () {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await initializeDateFormatting('id_ID');
    await _loadFont(AppTheme.fontFamily, [
      for (final w in ['Regular', 'Medium', 'Bold'])
        'assets/fonts/MPLUSRounded1c-$w.ttf',
    ]);
    final root = Platform.environment['FLUTTER_ROOT'];
    final icons =
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (root != null && File(icons).existsSync()) {
      await _loadFont('MaterialIcons', [icons]);
    }
  });

  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    Future<void> shoot(WidgetTester tester, Widget home, String file) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _withFakes(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: home,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(home),
        matchesGoldenFile('preview/${file}_$name.png'),
      );
    }

    testWidgets('pratinjau home $name', (tester) async {
      await shoot(tester, const MainShell(), 'home');
    }, skip: !_enabled);

    testWidgets('pratinjau kartu spot $name', (tester) async {
      await shoot(tester, const _SpotList(), 'spots');
    }, skip: !_enabled);

    testWidgets('pratinjau kuis $name', (tester) async {
      await shoot(tester, const QuizScreen(), 'quiz');
      // Pilih jawaban salah pada soal pertama agar warna benar/salah terlihat.
      final q = quizSeed[0];
      await tester.tap(find.text(q.options[(q.answerIndex + 1) % 4]));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(QuizScreen),
        matchesGoldenFile('preview/quiz_answered_$name.png'),
      );
    }, skip: !_enabled);

    testWidgets('pratinjau profil $name', (tester) async {
      await shoot(
        tester,
        PqBackground(
          child: ChangeNotifierProvider(
            create: (_) =>
                ThemeModeProvider(read: () async => null, write: (_) async {}),
            child: const ProfileScreen(),
          ),
        ),
        'profile',
      );
    }, skip: !_enabled);

    testWidgets('pratinjau login $name', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('preview/login_$name.png'),
      );
    }, skip: !_enabled);

    testWidgets('pratinjau galeri $name', (tester) async {
      tester.view.physicalSize = const Size(1170, 3900);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const _Gallery(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(_Gallery),
        matchesGoldenFile('preview/gallery_$name.png'),
      );
    }, skip: !_enabled);
  }
}

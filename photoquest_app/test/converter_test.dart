import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:photoquest_app/core/formatters.dart';
import 'package:photoquest_app/core/time_zones.dart';
import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/json_cache.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/local/weather_dao.dart';
import 'package:photoquest_app/data/models/currency.dart';
import 'package:photoquest_app/data/models/weather_info.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/api_exception.dart';
import 'package:photoquest_app/data/remote/converter_api.dart';
import 'package:photoquest_app/data/remote/weather_api.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/converter_repository.dart';
import 'package:photoquest_app/data/repositories/weather_repository.dart';
import 'package:photoquest_app/providers/converter_provider.dart';
import 'package:photoquest_app/providers/location_provider.dart';
import 'package:photoquest_app/providers/weather_provider.dart';
import 'package:photoquest_app/services/location_service.dart';
import 'package:photoquest_app/services/notification_service.dart';
import 'package:photoquest_app/ui/screens/converter_screen.dart';

final _client = ApiClient(SecureStore());
const _offline = ApiException('Tidak dapat terhubung', isNetworkError: true);

Map<String, dynamic> ratesJson() => {
  'base': 'IDR',
  'date': '2026-10-02',
  'source': 'live',
  'fetched_at': '2026-10-05T01:00:00.000Z',
  'rates': {'IDR': 1, 'USD': 1 / 16000, 'EUR': 1 / 20000, 'JPY': 1 / 125},
};

const _gearJson = [
  {'id': 1, 'name': 'Remote shutter', 'price_idr': 75000},
  {'id': 2, 'name': 'Tripod', 'price_idr': 480000},
];

class _FakeApi extends ConverterApi {
  _FakeApi({this.offline = false}) : super(_client);
  final bool offline;

  @override
  Future<Map<String, dynamic>> ratesRaw({String base = 'IDR'}) async =>
      offline ? throw _offline : ratesJson();

  @override
  Future<List<dynamic>> gearRaw() async => offline ? throw _offline : _gearJson;
}

/// Cache sqflite palsu di memori.
class _MemoryCache extends JsonCache {
  _MemoryCache() : super(DbHelper.instance, prefix: 'cache_app_');
  final store = <String, Object?>{};

  @override
  Future<void> save(String name, Object? json) async => store[name] = json;

  @override
  Future<({Object? data, DateTime savedAt})?> read(String name) async =>
      store.containsKey(name)
      ? (data: store[name], savedAt: DateTime(2026, 10, 4))
      : null;
}

class _FakeLocation extends LocationProvider {
  _FakeLocation() : super(LocationService(), DbHelper.instance);
}

class _FakeWeatherRepo extends WeatherRepository {
  _FakeWeatherRepo()
    : super(WeatherApi(_client), WeatherDao(DbHelper.instance));

  @override
  Future<CachedResult<WeatherInfo>> get(double lat, double lng) async =>
      CachedResult(WeatherInfo.estimate(DateTime.now()));
}

AppZone zone(String label) => appZones.firstWhere((z) => z.label == label);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    tzdata.initializeTimeZones();
  });

  group('Kurs', () {
    test('Konversi lewat IDR: 100 USD = Rp1.600.000 = €80 = ¥12.800', () {
      final r = CurrencyRates.fromJson(ratesJson());
      expect(r.convert(100, 'USD', 'IDR'), closeTo(1600000, 1e-6));
      expect(r.convert(100, 'USD', 'EUR'), closeTo(80, 1e-9));
      expect(r.convert(100, 'USD', 'JPY'), closeTo(12800, 1e-6));
      expect(r.convert(75000, 'IDR', 'IDR'), 75000);
    });

    test('Kurs fallback = kurs silang snapshot ECB (1 USD ≈ Rp17.950)', () {
      final r = CurrencyRates.fallback(DateTime(2026));
      expect(r.isFallback, isTrue);
      expect(r.convert(1, 'USD', 'IDR'), closeTo(17950.40, 0.01));
    });

    test('Format uang per mata uang', () {
      expect(Formatters.money(1500000, 'IDR'), 'Rp1.500.000');
      expect(Formatters.money(83.556, 'USD'), 'US\$83,56');
      expect(Formatters.money(13176.4, 'JPY'), '¥13.176');
    });

    test(
      'Repository offline tanpa cache -> kurs fallback; gear -> error',
      () async {
        final repo = ConverterRepository(
          _FakeApi(offline: true),
          _MemoryCache(),
        );
        final r = await repo.rates();
        expect(r.fromCache, isTrue);
        expect(r.data.isFallback, isTrue);
        expect(repo.gear(), throwsA(isA<ApiException>()));
      },
    );

    test('Repository offline dengan cache -> kurs & gear dari cache', () async {
      final cache = _MemoryCache();
      await ConverterRepository(_FakeApi(), cache).rates();
      await ConverterRepository(_FakeApi(), cache).gear();
      final offline = ConverterRepository(_FakeApi(offline: true), cache);
      expect((await offline.rates()).data.source, 'live');
      expect((await offline.gear()).data.map((g) => g.name), [
        'Remote shutter',
        'Tripod',
      ]);
    });

    test(
      'Provider: gear pertama otomatis dipilih, input manual USD dikonversi',
      () async {
        final p = ConverterProvider(
          ConverterRepository(_FakeApi(), _MemoryCache()),
        );
        await p.load();
        expect(p.selectedGear!.name, 'Remote shutter');
        expect(p.converted['USD'], closeTo(75000 / 16000, 1e-9));
        p.setManual(amount: 50, currency: 'USD');
        expect(p.selectedGear, isNull);
        expect(p.converted['IDR'], closeTo(800000, 1e-6));
      },
    );
  });

  group('Zona waktu', () {
    test('12.00 WIB = 13.00 WITA = 14.00 WIT', () {
      final t = TimeZoneConverter.fromWallClock(
        zone('WIB'),
        DateTime(2026, 10, 5),
        12,
        0,
      );
      expect(TimeZoneConverter.inZone(t, zone('WITA')).hour, 13);
      expect(TimeZoneConverter.inZone(t, zone('WIT')).hour, 14);
    });

    test(
      'London ikut daylight saving: Juli BST (UTC+1), Desember GMT (UTC+0)',
      () {
        final july = TimeZoneConverter.inZone(
          TimeZoneConverter.fromWallClock(
            zone('WIB'),
            DateTime(2026, 7, 1),
            12,
            0,
          ),
          zone('London'),
        );
        expect(july.hour, 6);
        expect(
          TimeZoneConverter.offsetLabel(july, zone('London')),
          'UTC+1 · BST',
        );

        final dec = TimeZoneConverter.inZone(
          TimeZoneConverter.fromWallClock(
            zone('WIB'),
            DateTime(2026, 12, 1),
            12,
            0,
          ),
          zone('London'),
        );
        expect(dec.hour, 5);
        expect(
          TimeZoneConverter.offsetLabel(dec, zone('London')),
          'UTC+0 · GMT',
        );
      },
    );

    test(
      'Pergantian hari ditandai: 03.00 WIB = 20.00 London hari sebelumnya',
      () {
        final wib = TimeZoneConverter.fromWallClock(
          zone('WIB'),
          DateTime(2026, 12, 2),
          3,
          0,
        );
        final london = TimeZoneConverter.inZone(wib, zone('London'));
        expect(
          TimeZoneConverter.clock(london, reference: wib),
          '20.00 (-1 hari)',
        );
      },
    );
  });

  group('Pengingat notifikasi', () {
    final now = DateTime(2026, 10, 5, 12);

    test('Pengingat 30 menit sebelum waktu rencana', () {
      expect(
        NotificationService.reminderTimeFor(DateTime(2026, 10, 5, 16, 32), now),
        DateTime(2026, 10, 5, 16, 2),
      );
    });

    test('Rencana kurang dari 30 menit lagi -> tidak dijadwalkan', () {
      expect(
        NotificationService.reminderTimeFor(DateTime(2026, 10, 5, 12, 20), now),
        isNull,
      );
    });

    test('ID pengingat unik per spot & waktu, muat di int32', () {
      final a = NotificationService.reminderId(
        14,
        DateTime(2026, 10, 5, 16, 32),
      );
      final b = NotificationService.reminderId(
        14,
        DateTime(2026, 10, 6, 16, 32),
      );
      final c = NotificationService.reminderId(
        15,
        DateTime(2026, 10, 5, 16, 32),
      );
      expect({a, b, c}, hasLength(3));
      expect(a < 2147483647, isTrue);
    });
  });

  testWidgets('Tab Kurs: sumber live, gear terpilih, hasil 4 mata uang', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ConverterRepository>.value(
            value: ConverterRepository(_FakeApi(), _MemoryCache()),
          ),
          ChangeNotifierProvider<LocationProvider>.value(
            value: _FakeLocation(),
          ),
          ChangeNotifierProvider(
            create: (_) => WeatherProvider(_FakeWeatherRepo()),
          ),
        ],
        child: const MaterialApp(home: ConverterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kurs: Live'), findsOneWidget);
    // Layar punya beberapa Scrollable (TabBarView + ListView) -> pilih ListView tab Kurs.
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Rp75.000'),
      200,
      scrollable: list.first,
    );
    expect(find.text('Rp75.000'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('¥600'),
      200,
      scrollable: list.first,
    );
    expect(find.text('¥600'), findsOneWidget); // 75.000 / 125
  });
}

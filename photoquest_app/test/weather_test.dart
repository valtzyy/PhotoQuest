import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/local/weather_dao.dart';
import 'package:photoquest_app/data/models/weather_info.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/api_exception.dart';
import 'package:photoquest_app/data/remote/open_meteo_api.dart';
import 'package:photoquest_app/data/remote/weather_api.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/weather_repository.dart';
import 'package:photoquest_app/ui/widgets/weather_widgets.dart';

/// Contoh respons GET /weather dari backend.
Map<String, dynamic> sampleJson({bool estimate = false}) => {
  'source': estimate ? 'estimate' : 'live',
  'is_estimate': estimate,
  'fetched_at': '2026-10-04T08:00:00.000Z',
  'timezone': 'Asia/Jakarta',
  'current': estimate
      ? null
      : {
          'time': '2026-10-04T15:00:00+07:00',
          'temperature': 30.1,
          'cloud_cover': 40,
          'weather_code': 2,
          'description': 'Berawan sebagian',
        },
  'days': [
    {
      'date': '2026-10-04',
      'sunrise': '2026-10-04T05:21:00+07:00',
      'sunset': '2026-10-04T17:32:00+07:00',
      'golden_morning': {
        'start': '2026-10-04T05:21:00+07:00',
        'end': '2026-10-04T06:21:00+07:00',
      },
      'golden_evening': {
        'start': '2026-10-04T16:32:00+07:00',
        'end': '2026-10-04T17:32:00+07:00',
      },
    },
  ],
  'hourly': [
    {
      'time': '2026-10-04T16:00:00+07:00',
      'cloud_cover': 35,
      'precipitation_probability': 10,
    },
    {
      'time': '2026-10-04T17:00:00+07:00',
      'cloud_cover': 50,
      'precipitation_probability': 20,
    },
  ],
};

/// Respons mentah Open-Meteo (sama dengan contoh di test backend).
Map<String, dynamic> openMeteoRaw() => {
  'timezone': 'Asia/Jakarta',
  'utc_offset_seconds': 25200,
  'current': {
    'time': '2026-10-04T15:00',
    'temperature_2m': 30.1,
    'cloud_cover': 40,
    'weather_code': 2,
  },
  'daily': {
    'time': ['2026-10-04', '2026-10-05'],
    'sunrise': ['2026-10-04T05:21', '2026-10-05T05:21'],
    'sunset': ['2026-10-04T17:32', '2026-10-05T17:32'],
  },
  'hourly': {
    'time': ['2026-10-04T16:00', '2026-10-04T17:00'],
    'cloud_cover': [35, 50],
    'precipitation_probability': [10, null],
  },
};

class _FakeDirect extends OpenMeteoApi {
  _FakeDirect(this.handler);
  final Future<Map<String, dynamic>> Function() handler;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetch(double lat, double lng) {
    calls++;
    return handler();
  }
}

class _FakeApi extends WeatherApi {
  _FakeApi(this.handler) : super(ApiClient(SecureStore()));
  final Future<Map<String, dynamic>> Function() handler;

  @override
  Future<Map<String, dynamic>> raw(double lat, double lng) => handler();
}

/// Cache sqflite palsu di memori.
class _MemoryDao extends WeatherDao {
  _MemoryDao() : super(DbHelper.instance);
  final store = <String, Map<String, dynamic>>{};

  @override
  Future<void> save(String key, Map<String, dynamic> json) async =>
      store[key] = json;

  @override
  Future<({Map<String, dynamic> json, DateTime fetchedAt})?> read(
    String key,
  ) async => store[key] == null
      ? null
      : (json: store[key]!, fetchedAt: DateTime(2026, 10, 4));
}

const _offline = ApiException(
  'Tidak dapat terhubung ke server',
  isNetworkError: true,
);

void main() {
  group('WeatherInfo', () {
    final info = WeatherInfo.fromJson(sampleJson());

    test('Parsing waktu ber-offset +07:00 menjadi instant yang benar', () {
      expect(info.days.first.sunrise, DateTime.utc(2026, 10, 3, 22, 21));
      expect(info.current!.description, 'Berawan sebagian');
    });

    test('dayFor memakai tanggal kalender WIB', () {
      // 23:00 UTC tgl 3 = 06:00 WIB tgl 4
      expect(info.dayFor(DateTime.utc(2026, 10, 3, 23))!.date, '2026-10-04');
      expect(info.dayFor(DateTime.utc(2026, 10, 5, 12)), isNull);
    });

    test('hourAt mengambil jam terdekat (maks. selisih 1 jam)', () {
      final t = DateTime.parse('2026-10-04T16:40:00+07:00');
      expect(info.hourAt(t)!.cloudCover, 50);
      expect(info.hourAt(DateTime.parse('2026-10-04T20:00:00+07:00')), isNull);
    });

    test(
      'Estimasi lokal: sunrise 05:30 & sunset 17:45 WIB, golden hour 60 menit',
      () {
        final e = WeatherInfo.estimate(
          DateTime.utc(2026, 10, 4, 20),
        ); // 03:00 WIB tgl 5
        final d = e.days.first;
        expect(e.isEstimate, isTrue);
        expect(d.date, '2026-10-05');
        expect(d.sunrise, DateTime.parse('2026-10-05T05:30:00+07:00'));
        expect(
          d.goldenEvening.start,
          DateTime.parse('2026-10-05T16:45:00+07:00'),
        );
        expect(d.goldenEvening.end, d.sunset);
      },
    );
  });

  test('goldenStatus: berlangsung / akan mulai / sudah lewat', () {
    final r = TimeRange(
      DateTime.parse('2026-10-04T16:32:00+07:00'),
      DateTime.parse('2026-10-04T17:32:00+07:00'),
    );
    expect(
      goldenStatus(r, DateTime.parse('2026-10-04T17:00:00+07:00')),
      'Sedang berlangsung',
    );
    expect(
      goldenStatus(r, DateTime.parse('2026-10-04T14:17:00+07:00')),
      'Mulai 2 j 15 mnt lagi',
    );
    expect(
      goldenStatus(r, DateTime.parse('2026-10-04T16:02:00+07:00')),
      'Mulai 30 mnt lagi',
    );
    expect(
      goldenStatus(r, DateTime.parse('2026-10-04T18:00:00+07:00')),
      'Sudah lewat',
    );
  });

  group('WeatherRepository fallback', () {
    test('Online -> data live dan disimpan ke cache', () async {
      final dao = _MemoryDao();
      final repo = WeatherRepository(_FakeApi(() async => sampleJson()), dao);
      final r = await repo.get(-7.7829, 110.3671);
      expect(r.fromCache, isFalse);
      expect(dao.store.keys, ['-7.78,110.37']);
    });

    test('Offline + ada cache -> data cache dengan fromCache', () async {
      final dao = _MemoryDao()..store['-7.78,110.37'] = sampleJson();
      final repo = WeatherRepository(_FakeApi(() => throw _offline), dao);
      final r = await repo.get(-7.7829, 110.3671);
      expect(r.fromCache, isTrue);
      expect(r.data.isEstimate, isFalse);
    });

    test('Offline + tanpa cache -> estimasi lokal', () async {
      final repo = WeatherRepository(
        _FakeApi(() => throw _offline),
        _MemoryDao(),
      );
      final r = await repo.get(-7.78, 110.37);
      expect(r.data.isEstimate, isTrue);
      expect(r.data.days, hasLength(7));
    });

    test(
      'Server memberi estimasi tapi HP punya data asli lama -> pakai data lama, '
      'bukan "offline" karena server terjangkau',
      () async {
        final dao = _MemoryDao()..store['-7.78,110.37'] = sampleJson();
        final repo = WeatherRepository(
          _FakeApi(() async => sampleJson(estimate: true)),
          dao,
        );
        final r = await repo.get(-7.78, 110.37);
        expect(r.data.isEstimate, isFalse);
        expect(r.fromCache, isFalse);
        expect(r.cachedAt, isNotNull);
      },
    );
  });

  group('WeatherSourceChip: label sesuai kondisi sebenarnya', () {
    Future<void> pumpChip(
      WidgetTester tester,
      CachedResult<WeatherInfo> result,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WeatherSourceChip(result: result)),
      ),
    );

    testWidgets('Live', (tester) async {
      await pumpChip(tester, CachedResult(WeatherInfo.fromJson(sampleJson())));
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('Cache server', (tester) async {
      final json = sampleJson()..['source'] = 'cache';
      await pumpChip(tester, CachedResult(WeatherInfo.fromJson(json)));
      expect(find.text('Cache server'), findsOneWidget);
    });

    testWidgets('Server terjangkau, memakai data lama HP -> bukan "Offline"', (
      tester,
    ) async {
      await pumpChip(
        tester,
        CachedResult(
          WeatherInfo.fromJson(sampleJson()),
          cachedAt: DateTime(2026, 10, 4),
        ),
      );
      expect(find.text('Data lama (HP)'), findsOneWidget);
      expect(find.text('Offline (cache)'), findsNothing);
    });

    testWidgets('Server tak terjangkau -> Offline (cache)', (tester) async {
      await pumpChip(
        tester,
        CachedResult(
          WeatherInfo.fromJson(sampleJson()),
          fromCache: true,
          cachedAt: DateTime(2026, 10, 4),
        ),
      );
      expect(find.text('Offline (cache)'), findsOneWidget);
    });

    testWidgets('Tanpa data cuaca -> jadwal dihitung, bukan "Estimasi"', (
      tester,
    ) async {
      await pumpChip(
        tester,
        CachedResult(WeatherInfo.fromJson(sampleJson(estimate: true))),
      );
      expect(find.text('Jadwal dihitung'), findsOneWidget);
    });
  });

  group('Open-Meteo langsung dari HP (server kena 429)', () {
    test('mapper menghasilkan format yang sama dengan backend', () {
      final json = openMeteoToWeatherJson(
        openMeteoRaw(),
        DateTime.utc(2026, 10, 4, 8),
      );
      expect(json['source'], 'live');
      expect(json['is_estimate'], false);
      final day = (json['days'] as List).first as Map<String, dynamic>;
      expect(day['sunrise'], '2026-10-04T05:21:00+07:00');
      expect(day['golden_morning'], {
        'start': '2026-10-04T05:21:00+07:00',
        'end': '2026-10-04T06:21:00+07:00',
      });
      expect(day['golden_evening'], {
        'start': '2026-10-04T16:32:00+07:00',
        'end': '2026-10-04T17:32:00+07:00',
      });
      final hourly = json['hourly'] as List;
      expect((hourly.first as Map)['time'], '2026-10-04T16:00:00+07:00');
      final info = WeatherInfo.fromJson(json);
      expect(info.current!.description, 'Berawan sebagian');
      expect(info.current!.temperature, 30.1);
      expect(info.hourly[1].precipitationProbability, 0); // null -> 0
    });

    test('Server memberi estimasi -> HP ambil langsung, hasil Live & disimpan',
        () async {
      final dao = _MemoryDao();
      final direct = _FakeDirect(() async => openMeteoRaw());
      final repo = WeatherRepository(
        _FakeApi(() async => sampleJson(estimate: true)),
        dao,
        direct: direct,
        now: () => DateTime.utc(2026, 10, 4, 8),
      );
      final r = await repo.get(-7.78, 110.37);
      expect(direct.calls, 1);
      expect(r.data.isEstimate, isFalse);
      expect(r.data.source, 'live');
      expect(r.fromCache, isFalse);
      expect(r.cachedAt, isNull);
      expect(dao.store.keys, ['-7.78,110.37']);
    });

    test('Server tak terjangkau tapi internet HP ada -> tetap Live', () async {
      final repo = WeatherRepository(
        _FakeApi(() => throw _offline),
        _MemoryDao(),
        direct: _FakeDirect(() async => openMeteoRaw()),
        now: () => DateTime.utc(2026, 10, 4, 8),
      );
      final r = await repo.get(-7.78, 110.37);
      expect(r.data.source, 'live');
      expect(r.fromCache, isFalse);
    });

    test('Server live -> Open-Meteo langsung tidak dipanggil', () async {
      final direct = _FakeDirect(() async => openMeteoRaw());
      final repo = WeatherRepository(
        _FakeApi(() async => sampleJson()),
        _MemoryDao(),
        direct: direct,
      );
      await repo.get(-7.78, 110.37);
      expect(direct.calls, 0);
    });

    test('Server estimasi + Open-Meteo HP gagal + tanpa cache -> estimasi server',
        () async {
      final repo = WeatherRepository(
        _FakeApi(() async => sampleJson(estimate: true)),
        _MemoryDao(),
        direct: _FakeDirect(() => throw Exception('429')),
      );
      final r = await repo.get(-7.78, 110.37);
      expect(r.data.isEstimate, isTrue);
      expect(r.fromCache, isFalse);
    });

    test('Semua gagal (offline sungguhan) + ada cache -> Offline (cache)',
        () async {
      final dao = _MemoryDao()..store['-7.78,110.37'] = sampleJson();
      final repo = WeatherRepository(
        _FakeApi(() => throw _offline),
        dao,
        direct: _FakeDirect(() => throw Exception('no internet')),
      );
      final r = await repo.get(-7.78, 110.37);
      expect(r.fromCache, isTrue);
      expect(r.data.isEstimate, isFalse);
    });

    test('Error server non-jaringan (mis. 401) tetap dilempar, tanpa fallback',
        () async {
      final direct = _FakeDirect(() async => openMeteoRaw());
      final repo = WeatherRepository(
        _FakeApi(() => throw const ApiException('Sesi habis', statusCode: 401)),
        _MemoryDao(),
        direct: direct,
      );
      await expectLater(repo.get(-7.78, 110.37), throwsA(isA<ApiException>()));
      expect(direct.calls, 0);
    });
  });
}

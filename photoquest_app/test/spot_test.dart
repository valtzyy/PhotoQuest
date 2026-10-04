import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/local/spot_dao.dart';
import 'package:photoquest_app/data/models/spot.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/api_exception.dart';
import 'package:photoquest_app/data/remote/spot_api.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/spot_repository.dart';
import 'package:photoquest_app/providers/spot_provider.dart';
import 'package:photoquest_app/ui/screens/explore_screen.dart';

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

final _all = [
  _spot(1, 'Candi Prambanan', 'culture'),
  _spot(2, 'Pantai Parangtritis', 'landscape'),
  _spot(3, 'Jalan Malioboro', 'street'),
];

/// Repository palsu: memfilter data di memori, bisa diatur lambat/offline.
class _FakeRepo extends SpotRepository {
  _FakeRepo()
    : super(SpotApi(ApiClient(SecureStore())), SpotDao(DbHelper.instance));

  final calls = <String>[];
  final Map<String, Completer<void>> delays = {};
  bool offlineFavorites = false;

  @override
  Future<CachedResult<List<Spot>>> getSpots({
    String? search,
    String? category,
  }) async {
    final key = '${search ?? ''}|${category ?? ''}';
    calls.add(key);
    if (delays[key] != null) await delays[key]!.future;
    final q = (search ?? '').toLowerCase();
    return CachedResult(
      _all
          .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
          .where((s) => category == null || s.category == category)
          .toList(),
    );
  }

  @override
  Future<CachedResult<Set<int>>> favoriteIds() async => const CachedResult({2});

  @override
  Future<void> setFavorite(int spotId, bool favorite) async {
    if (offlineFavorites) {
      throw const ApiException('Sedang offline.', isNetworkError: true);
    }
  }
}

void main() {
  test('Spot: JSON server -> baris sqflite -> Spot tetap sama', () {
    final json = {
      'id': 7,
      'name': 'Tebing Breksi',
      'category': 'landscape',
      'description': 'Tebing',
      'latitude': -7.782,
      'longitude': 110.5048,
      'best_time': 'sunset',
      'photo_types': ['landscape', 'sunset'],
      'tips': null,
      'image_url': null,
      'entry_fee_idr': 10000,
    };
    final fromApi = Spot.fromJson(json);
    final fromDb = Spot.fromDb(fromApi.toDb(DateTime(2026)));
    expect(fromDb.name, 'Tebing Breksi');
    expect(fromDb.photoTypes, ['landscape', 'sunset']);
    expect(fromDb.entryFeeIdr, 10000);
    expect(fromDb.latitude, -7.782);
  });

  group('SpotProvider', () {
    test(
      'Search di-debounce: ketik cepat hanya memanggil API sekali',
      () async {
        final repo = _FakeRepo();
        final p = SpotProvider(repo);
        p.setQuery('p');
        p.setQuery('pa');
        p.setQuery('pantai');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(repo.calls, ['pantai|']);
        expect(p.spots.map((s) => s.name), ['Pantai Parangtritis']);
      },
    );

    test('Respons lama yang datang terlambat diabaikan', () async {
      final repo = _FakeRepo();
      final p = SpotProvider(repo);
      final slow = Completer<void>();
      repo.delays['|culture'] = slow;

      final first = p.loadSpots().then((_) {}); // tanpa filter, cepat
      await first;
      p.setCategory('culture'); // lambat
      p.setCategory('street'); // cepat, lebih baru
      await Future<void>.delayed(Duration.zero);
      slow.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(p.category, 'street');
      expect(p.spots.map((s) => s.name), ['Jalan Malioboro']);
    });

    test('Filter Favorit hanya menampilkan spot favorit', () async {
      final p = SpotProvider(_FakeRepo());
      await p.refresh();
      expect(p.visibleSpots.length, 3);
      p.setFavoritesOnly(true);
      expect(p.visibleSpots.map((s) => s.id), [2]);
    });

    test(
      'Toggle favorit saat offline -> pesan error, state tidak berubah',
      () async {
        final repo = _FakeRepo()..offlineFavorites = true;
        final p = SpotProvider(repo);
        await p.refresh();
        final error = await p.toggleFavorite(1);
        expect(error, contains('offline'));
        expect(p.isFavorite(1), isFalse);
      },
    );

    test(
      'clearUserState mengosongkan favorit (dipanggil saat logout)',
      () async {
        final p = SpotProvider(_FakeRepo());
        await p.refresh();
        p.clearUserState();
        expect(p.favoriteIds, isEmpty);
      },
    );
  });

  testWidgets('Explore: chip kategori memfilter daftar', (tester) async {
    final p = SpotProvider(_FakeRepo());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Candi Prambanan'), findsOneWidget);
    expect(find.text('Jalan Malioboro'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Jalanan'));
    await tester.pumpAndSettle();
    expect(find.text('Candi Prambanan'), findsNothing);
    expect(find.text('Jalan Malioboro'), findsOneWidget);
  });
}

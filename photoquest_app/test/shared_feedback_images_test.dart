// Uji model Saran & Kesan bersama (semua pengguna) dan foto spot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photoquest_app/data/models/feedback_item.dart';
import 'package:photoquest_app/data/models/spot.dart';
import 'package:photoquest_app/ui/widgets/spot_image.dart';
import 'package:photoquest_app/ui/widgets/spot_placeholder.dart';

Spot _spot({String? imageUrl}) => Spot(
  id: 1,
  name: 'Tugu Jogja',
  category: 'architecture',
  description: 'd',
  latitude: -7.78,
  longitude: 110.36,
  bestTime: 'sunset',
  photoTypes: const ['architecture'],
  imageUrl: imageUrl,
);

void main() {
  test('FeedbackItem membaca nama penulis dan penanda milik sendiri', () {
    final item = FeedbackItem.fromJson({
      'id': 3,
      'saran': 's',
      'kesan': 'k',
      'created_at': '2026-10-15T01:00:00.000Z',
      'name': 'Budi',
      'mine': true,
    });
    expect(item.authorName, 'Budi');
    expect(item.mine, isTrue);
    // Bolak-balik JSON (dipakai cache offline) tidak menghilangkan field baru.
    final again = FeedbackItem.fromJson(item.toJson());
    expect(again.authorName, 'Budi');
    expect(again.mine, isTrue);
  });

  test('FeedbackItem lama (tanpa name/mine) tetap terbaca', () {
    final item = FeedbackItem.fromJson({
      'id': 1,
      'saran': 's',
      'kesan': 'k',
      'created_at': '2026-10-15T01:00:00.000Z',
    });
    expect(item.authorName, isNull);
    expect(item.mine, isFalse);
  });

  test('Spot menyimpan image_credit lewat JSON dan cache sqflite', () {
    final spot = Spot.fromJson({
      'id': 1,
      'name': 'Tugu Jogja',
      'category': 'architecture',
      'description': 'd',
      'latitude': -7.78,
      'longitude': 110.36,
      'best_time': 'sunset',
      'photo_types': ['architecture'],
      'image_url': 'https://commons.wikimedia.org/x.jpg',
      'image_credit': 'Fulan / Wikimedia Commons, CC BY-SA 4.0',
    });
    expect(spot.imageCredit, contains('Wikimedia Commons'));
    final row = spot.toDb(DateTime(2026, 10, 15));
    expect(row['image_credit'], spot.imageCredit);
  });

  testWidgets('SpotImage memakai placeholder bila belum ada URL', (t) async {
    await t.pumpWidget(MaterialApp(home: SpotImage(spot: _spot())));
    expect(find.byType(SpotPlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('SpotImage memuat gambar jaringan dan menyiapkan fallback', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: SpotImage(spot: _spot(imageUrl: 'https://x.test/a.jpg')),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    // Di lingkungan tes request jaringan gagal -> errorBuilder menampilkan placeholder.
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(SpotPlaceholder), findsOneWidget);
    await t.pumpWidget(
      const SizedBox(),
    ); // lepas widget (membatalkan timer retry)
  });

  testWidgets('SpotImage mencoba memuat ulang sendiri setelah gagal', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: SpotImage(spot: _spot(imageUrl: 'https://x.test/a.jpg')),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    Key? imageKey() => t.widget<Image>(find.byType(Image)).key;
    expect(imageKey(), const ValueKey('https://x.test/a.jpg#0'));

    // Jeda pertama 2 detik: Image dibangun ulang dengan kunci baru (percobaan ke-1).
    await t.pump(SpotImage.retryBaseDelay + const Duration(milliseconds: 50));
    expect(imageKey(), const ValueKey('https://x.test/a.jpg#1'));
    await t.pumpWidget(const SizedBox());
  });
}

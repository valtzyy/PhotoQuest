import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/amount_parser.dart';

double? v(String text) => AmountParser.parse(text).value;
String? e(String text) => AmountParser.parse(text).error;

void main() {
  group('Pembaca angka input Kurs', () {
    test('Kosong dianggap 0 tanpa pesan error', () {
      expect(v(''), 0);
      expect(v('   '), 0);
      expect(e(''), isNull);
    });

    test('Bilangan bulat dan desimal biasa', () {
      expect(v('1500000'), 1500000);
      expect(v('83,5'), 83.5);
      expect(v('83.5'), 83.5);
      expect(v('199,99'), 199.99);
      expect(v('0,5'), 0.5);
      expect(v('0.123'), 0.123); // diawali 0 -> desimal, bukan ribuan
      expect(v('1.2345'), 1.2345); // 4 digit di belakang -> desimal
    });

    test(
      'Titik/koma + tepat 3 digit = pemisah ribuan (kebiasaan Indonesia)',
      () {
        expect(v('1.000'), 1000);
        expect(v('1,000'), 1000);
        expect(v('12.345'), 12345);
        expect(v('1.000.000'), 1000000);
        expect(v('1,000,000'), 1000000);
      },
    );

    test('Campuran: pemisah terakhir adalah desimal', () {
      expect(v('1.234,56'), 1234.56);
      expect(v('1,234.56'), 1234.56);
      expect(v('1.000.000,5'), 1000000.5);
    });

    test('Format tidak valid -> pesan error, bukan 0 diam-diam', () {
      for (final bad in [
        '1.2.3',
        '1..0',
        '1.00.000',
        '1,234.567,8',
        ',',
        '.',
        '1,2,3',
      ]) {
        expect(v(bad), isNull, reason: bad);
        expect(e(bad), 'Format angka tidak valid', reason: bad);
      }
    });

    test('Batas atas 999.999.999.999: di atasnya ditolak dengan pesan', () {
      expect(v('999999999999'), 999999999999);
      expect(v('999.999.999.999'), 999999999999);
      for (final big in [
        '1000000000000',
        '1000000000000000000',
        '10000000000000000000', // kasus yang tadinya jadi 9.223.372...
        '9' * 40,
      ]) {
        expect(v(big), isNull, reason: big);
        expect(e(big), 'Maksimal 999.999.999.999', reason: big);
      }
    });
  });
}

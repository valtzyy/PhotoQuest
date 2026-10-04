import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/main.dart';

void main() {
  testWidgets('Aplikasi tampil dengan layar cek backend', (tester) async {
    await tester.pumpWidget(const PhotoQuestApp());
    expect(find.text('PhotoQuest – Cek Backend'), findsOneWidget);
    // Majukan waktu melewati timeout 8 detik agar timer request dio selesai.
    await tester.pump(const Duration(seconds: 10));
  });
}

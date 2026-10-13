import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/core/theme.dart';
import 'package:photoquest_app/providers/theme_mode_provider.dart';
import 'package:photoquest_app/ui/widgets/theme_mode_tile.dart';

/// Penyimpanan palsu di memori pengganti tabel settings.
class _Store {
  _Store([this.value]);
  String? value;
  final writes = <String>[];

  ThemeModeProvider provider() => ThemeModeProvider(
    read: () async => value,
    write: (v) async {
      value = v;
      writes.add(v);
    },
  );
}

void main() {
  test('default Sistem sebelum dimuat', () {
    expect(_Store().provider().mode, ThemeMode.system);
  });

  test('memuat pilihan tersimpan', () async {
    final p = _Store('dark').provider();
    await p.load();
    expect(p.mode, ThemeMode.dark);
  });

  test('nilai kosong atau tak dikenal jatuh ke Sistem', () async {
    for (final saved in [null, 'ungu']) {
      final p = _Store(saved).provider();
      await p.load();
      expect(p.mode, ThemeMode.system, reason: 'saved=$saved');
    }
  });

  test('setMode menyimpan dan memberi tahu listener', () async {
    final store = _Store();
    final p = store.provider();
    var notified = 0;
    p.addListener(() => notified++);

    await p.setMode(ThemeMode.light);
    expect(p.mode, ThemeMode.light);
    expect(store.writes, ['light']);
    expect(notified, 1);

    await p.setMode(ThemeMode.light); // sama -> tidak menulis ulang
    expect(store.writes, ['light']);
    expect(notified, 1);
  });

  testWidgets('tile: tap Gelap mengganti mode', (tester) async {
    final store = _Store();
    final p = store.provider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ThemeModeTile()),
        ),
      ),
    );
    expect(find.text('Tema tampilan'), findsOneWidget);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(p.mode, ThemeMode.dark);
    expect(store.writes, ['dark']);
  });

  testWidgets('tile kosong bila provider tidak dipasang', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThemeModeTile())),
    );
    expect(find.text('Tema tampilan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

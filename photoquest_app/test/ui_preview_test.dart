import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/pq_colors.dart';
import 'package:photoquest_app/core/theme.dart';
import 'package:photoquest_app/ui/screens/login_screen.dart';
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

void main() {
  setUpAll(() async {
    if (!_enabled) return;
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

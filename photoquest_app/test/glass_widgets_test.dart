import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/pq_colors.dart';
import 'package:photoquest_app/core/theme.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_icon_tile.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_panel.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_pill.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_pressable.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_progress_bar.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_surface.dart';
import 'package:photoquest_app/ui/widgets/glass/holo_card_frame.dart';
import 'package:photoquest_app/ui/widgets/glass/pq_background.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// Pergeseran vertikal permukaan kaca (0 = diam, 3 = amblas penuh).
double _dy(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .storage[13];

void main() {
  testWidgets('tap memanggil onTap sekali', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(GlassPressable(onTap: () => taps++, child: const Text('Tekan'))),
    );
    await tester.tap(find.text('Tekan'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('amblas sedalam bibir saat ditekan lalu kembali', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(GlassPressable(onTap: () {}, child: const Text('Tekan'))),
    );
    expect(_dy(tester), 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tekan')),
    );
    await tester.pump(); // frame tempat animasi tekan dimulai
    await tester.pump(const Duration(milliseconds: 150));
    expect(_dy(tester), closeTo(GlassSurface.lip, 0.01));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_dy(tester), closeTo(0, 0.01));
  });

  testWidgets('tanpa onTap tidak amblas', (tester) async {
    await tester.pumpWidget(_host(const GlassPressable(child: Text('Diam'))));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Diam')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_dy(tester), 0);
    await gesture.up();
  });

  testWidgets('tone berwarna membuat teks memakai onColor', (tester) async {
    await tester.pumpWidget(
      _host(
        GlassPressable(
          tone: GlassTone.blue,
          onTap: () {},
          child: const Text('Biru'),
        ),
      ),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('Biru'))).style;
    expect(style.color, Colors.white);
  });

  testWidgets('GlassProgressBar menjepit nilai di luar 0..1 dan NaN', (
    tester,
  ) async {
    for (final (value, expected) in [
      (1.5, 1.0),
      (-0.2, 0.0),
      (double.nan, 0.0),
      (0.3, 0.3),
    ]) {
      await tester.pumpWidget(_host(GlassProgressBar(value: value)));
      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, expected, reason: 'value=$value');
    }
  });

  testWidgets('HoloCardFrame bisa ditekan', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(HoloCardFrame(onTap: () => taps++, child: const Text('Spot'))),
    );
    await tester.tap(find.text('Spot'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('komponen tampil tanpa error (${theme.brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: PqBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: ListView(
                children: const [
                  GlassPanel(blur: true, child: Text('Panel')),
                  GlassIconTile(icon: Icons.explore, colors: PqPalette.tileRed),
                  GlassPill(label: 'Soal 3/10'),
                  GlassProgressBar(value: 0.5),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Soal 3/10'), findsOneWidget);
    });
  }
}

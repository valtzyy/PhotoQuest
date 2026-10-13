import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/pq_colors.dart';
import 'package:photoquest_app/core/theme.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_surface.dart';

void main() {
  testWidgets('PqColors.of jatuh ke light bila theme tanpa extension', (
    tester,
  ) async {
    late PqColors colors;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            colors = PqColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, same(PqColors.light));
  });

  testWidgets('PqColors.of jatuh ke dark bila brightness gelap', (
    tester,
  ) async {
    late PqColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            colors = PqColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, same(PqColors.dark));
  });

  test('tone() memetakan setiap GlassTone', () {
    expect(
      PqColors.light.tone(GlassTone.neutral),
      same(PqColors.light.neutral),
    );
    expect(PqColors.dark.tone(GlassTone.neutral), same(PqColors.dark.neutral));
    expect(PqColors.light.tone(GlassTone.blue), same(PqPalette.blueTone));
    expect(PqColors.light.tone(GlassTone.yellow), same(PqPalette.yellowTone));
    expect(PqColors.light.tone(GlassTone.red), same(PqPalette.redTone));
    expect(PqColors.light.tone(GlassTone.green), same(PqPalette.greenTone));
  });

  test('teks isi abu-abu, bukan hitam', () {
    expect(PqColors.light.text, const Color(0xFF56627A));
    expect(PqColors.light.heading, const Color(0xFF424E66));
  });

  test('AppTheme memasang PqColors dan font', () {
    expect(AppTheme.light.extension<PqColors>(), same(PqColors.light));
    expect(AppTheme.dark.extension<PqColors>(), same(PqColors.dark));
    expect(
      AppTheme.light.textTheme.bodyMedium?.fontFamily,
      AppTheme.fontFamily,
    );
    expect(AppTheme.light.textTheme.bodyMedium?.fontWeight, FontWeight.w500);
    expect(AppTheme.light.textTheme.titleLarge?.fontWeight, FontWeight.w700);
    expect(AppTheme.light.textTheme.bodyMedium?.color, PqColors.light.text);
  });

  Widget themed(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  double dy(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(GlassSurface),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .storage[13];

  testWidgets('FilledButton bertema amblas saat ditekan', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(FilledButton(onPressed: () => taps++, child: const Text('Masuk'))),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Masuk')),
    );
    await tester.pump(); // frame tempat animasi tekan dimulai
    await tester.pump(const Duration(milliseconds: 150));
    expect(dy(tester), closeTo(GlassSurface.lip, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dy(tester), closeTo(0, 0.01));
    expect(taps, 1);
  });

  testWidgets('FilledButton nonaktif redup dan tidak amblas', (tester) async {
    await tester.pumpWidget(
      themed(const FilledButton(onPressed: null, child: Text('Masuk'))),
    );
    expect(
      find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byType(Opacity),
      ),
      findsOneWidget,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Masuk')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(dy(tester), 0);
    await gesture.up();
  });

  testWidgets('ikon IconButton.filled memakai onPrimary, bukan warna teks', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        IconButton.filled(onPressed: () {}, icon: const Icon(Icons.camera_alt)),
      ),
    );
    final color = IconTheme.of(tester.element(find.byIcon(Icons.camera_alt)))
        .color;
    expect(color, AppTheme.light.colorScheme.onPrimary);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('dialog date/time picker opak (${theme.brightness.name})', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );

      showDatePicker(
        context: ctx,
        firstDate: DateTime(2026),
        lastDate: DateTime(2027),
        initialDate: DateTime(2026, 10, 13),
      );
      await tester.pumpAndSettle();
      final dateBg = tester.widget<Dialog>(find.byType(Dialog)).backgroundColor;
      expect(dateBg?.a, 1.0, reason: 'date picker backgroundColor=$dateBg');
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      showTimePicker(
        context: ctx,
        initialTime: const TimeOfDay(hour: 17, minute: 0),
      );
      await tester.pumpAndSettle();
      final timeBg = tester.widget<Dialog>(find.byType(Dialog)).backgroundColor;
      expect(timeBg?.a, 1.0, reason: 'time picker backgroundColor=$timeBg');
      final tp = theme.timePickerTheme;
      expect(tp.dialBackgroundColor?.a, 1.0);
      expect(tp.hourMinuteColor?.a, 1.0);
      // Kotak jam/menit yang sedang dipilih tetap disorot (beda warna).
      final selected = WidgetStateProperty.resolveAs(tp.hourMinuteColor, {
        WidgetState.selected,
      });
      final idle = WidgetStateProperty.resolveAs(
        tp.hourMinuteColor,
        <WidgetState>{},
      );
      expect(selected?.a, 1.0);
      expect(selected, isNot(idle));
    });
  }

  testWidgets('spinner loading di tombol nonaktif memakai warna onColor', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const FilledButton(
          onPressed: null,
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
    final indicatorTheme = ProgressIndicatorTheme.of(
      tester.element(find.byType(CircularProgressIndicator)),
    );
    expect(indicatorTheme.color, PqPalette.blueTone.onColor);
  });

  testWidgets('label tombol nonaktif hanya diredupkan sekali (Opacity)', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const FilledButton(onPressed: null, child: Text('Analisis'))),
    );
    final style = DefaultTextStyle.of(tester.element(find.text('Analisis')));
    expect(style.style.color, PqPalette.blueTone.onColor);
  });

  testWidgets('OutlinedButton bertema juga memakai GlassSurface', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(OutlinedButton(onPressed: () {}, child: const Text('Ulangi'))),
    );
    expect(find.byType(GlassSurface), findsOneWidget);
  });
}

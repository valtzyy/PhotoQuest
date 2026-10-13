# Redesign UI Glassy TCG — Rencana Implementasi

> **Untuk agen pelaksana:** WAJIB memakai sub-skill superpowers:subagent-driven-development (direkomendasikan) atau superpowers:executing-plans untuk menjalankan rencana ini per task. Langkah memakai checkbox (`- [ ]`) untuk pelacakan.

**Goal:** Mengganti tampilan seluruh aplikasi Flutter PhotoQuest ke gaya "glassy TCG", yaitu tombol kaca semi-transparan dengan bibir 3D tipis yang amblas saat ditekan, panel frosted, dan teks abu-abu kebiruan, tanpa mengubah fungsi.

**Architecture:** Token warna dibuat sebagai `ThemeExtension` (`PqColors`). Satu widget inti, `GlassSurface`, menggambar kaca, kilap, bibir, dan animasi tekan. Widget ini dipakai oleh theme (`ButtonStyle.backgroundBuilder`, sehingga `FilledButton` dan `OutlinedButton` berubah otomatis) dan oleh `GlassPressable` (untuk tile, jawaban kuis, dan kartu). Layar hanya dibungkus `PqBackground` dan disesuaikan di beberapa titik. Provider, repository, dan API tidak disentuh.

**Tech Stack:** Flutter 3.47 (Material 3, `WidgetState`), `flutter_test`, font M PLUS Rounded 1c (OFL, dibundel).

**Spec:** `docs/superpowers/specs/2026-10-13-ui-glassy-tcg-redesign-design.md`

## Batasan global

- Semua perintah Flutter dijalankan dari `photoquest_app/`.
- Hanya boleh mengubah: `lib/core/theme.dart`, `lib/core/pq_colors.dart` (baru), `lib/core/condition_score.dart` (baru), `lib/ui/**`, `pubspec.yaml` (blok `fonts:`), `assets/fonts/**`, `test/` (test baru), dan `.gitignore` (satu baris).
- Dilarang mengubah `lib/data`, `lib/providers`, `lib/services`, `lib/main.dart`, `photoquest_api`, dan test lama.
- Tidak boleh menambah package di `dependencies`.
- Tipe widget yang dicari test harus tetap ada: `NavigationBar`, `ChoiceChip`, `TextFormField`, `TextField`, `ListView`, `Scrollable`.
- Teks yang dicari test tidak boleh berubah, misalnya `'Soal 1 dari 2'`, `'Benar!'`, `'Lanjut'`, `'Skor 1 / 2'`, `'Home'`, `'Profil'`, `'Saran & Kesan'`, `'Logout'`, dan nama spot.
- Bobot font hanya 400, 500, dan 700. Teks isi 500, judul 700.
- Bibir 3D 3 px. Tekan: 50 ms `easeOut`. Lepas: 220 ms `Cubic(0.3, 1.8, 0.5, 1)`.
- `BackdropFilter` hanya dipakai di bottom nav (lewat `GlassPanel(blur: true)`), tidak di tombol.
- **Pengguna commit sendiri.** Langkah "Commit" berarti menampilkan saran pesan commit, bukan menjalankan `git commit`.
- Setelah Task 4, 5, 7, dan 9: **berhenti dan lapor ke pengguna** (akhir Tahap 1–4).
- Satu-satunya logika baru adalah `lib/core/condition_score.dart` (Task 6), yang disetujui pengguna. Rumusnya harus identik dengan `photoquest_api/src/services/scoreService.js`, tanpa komponen spot, lalu diskalakan dari 90 ke 100.

## Fokus review

1. **Widget dipasang tanpa `AppTheme`.** Test lama memakai `MaterialApp` polos, jadi `PqColors.of` harus jatuh ke `PqColors.light` dan tidak boleh crash. Dicakup Task 1.
2. **Tombol nonaktif** (misalnya `onPressed: null` saat login loading) harus tampak redup, tidak turun saat ditekan, dan tidak memicu haptic. Dicakup Task 3.
3. **Nilai progres di luar rentang 0–1 atau NaN** (misalnya skor dibagi `max` = 0) tidak boleh memicu assertion `FractionallySizedBox`. Dicakup Task 4.
4. **Bibir 3D tidak boleh tembus ke kaca transparan.** Kalau bibir digambar sebagai `BoxShadow` biasa, warnanya akan menodai isi tombol. Painter harus meng-clip area muka tombol. Diverifikasi lewat pratinjau golden di Task 4.
5. **Mode gelap dan label panjang** (misalnya "Level & Stabilizer" atau nama pengguna panjang) tetap terbaca dan tidak overflow. Dicek di pratinjau gelap Task 4, test `maxLines` di Task 7, dan seluruh `flutter test`.

---

## Struktur file

| File | Status | Tanggung jawab |
|---|---|---|
| `lib/core/pq_colors.dart` | baru | `GlassTone`, `GlassToneColors`, `PqPalette` (konstanta), `PqColors` (ThemeExtension + `of`) |
| `lib/core/theme.dart` | ubah total | `AppTheme.light/dark`: font, ColorScheme, TextTheme, semua component theme |
| `lib/ui/widgets/glass/glass_surface.dart` | baru | Kaca, kilap (`glassGloss`), bibir (`_LipPainter`), animasi tekan, dan haptic |
| `lib/ui/widgets/glass/glass_pressable.dart` | baru | `GlassPressable` dan `onColorTheme()` |
| `lib/ui/widgets/glass/pq_background.dart` | baru | Latar dasar dengan bercak radial |
| `lib/ui/widgets/glass/glass_panel.dart` | baru | Panel frosted, blur opsional |
| `lib/ui/widgets/glass/glass_icon_tile.dart` | baru | Tile ikon bergradien |
| `lib/ui/widgets/glass/glass_pill.dart` | baru | Lencana pil |
| `lib/ui/widgets/glass/glass_progress_bar.dart` | baru | Bar progres berkilap |
| `lib/ui/widgets/glass/holo_card_frame.dart` | baru | Bingkai kartu holo yang bisa ditekan |
| `lib/core/condition_score.dart` | baru | Skor kondisi "sekarang" untuk Home (porting rumus backend) |
| `test/condition_score_test.dart` | baru | Test rumus skor dengan angka acuan dari test backend |
| `test/pq_theme_test.dart` | baru | Test token, theme, dan tombol bertema |
| `test/glass_widgets_test.dart` | baru | Test `GlassPressable` dan komponen |
| `test/ui_preview_test.dart` | baru | Pratinjau golden (hanya jalan dengan `--dart-define=PQ_PREVIEW=true`) |
| `lib/ui/screens/*.dart`, `lib/ui/widgets/*.dart` | ubah | Restyle per layar (Task 5 dan 7–9) |

Catatan penyimpangan dari spec:
- `PqScaffold` tidak dibuat. Polanya adalah `PqBackground(child: Scaffold(backgroundColor: Colors.transparent, ...))`, yang lebih sederhana tanpa membungkus API `Scaffold`.
- Header `spot_detail` tetap `SliverAppBar` dengan placeholder berpalet baru, tanpa bingkai holo, karena `FlexibleSpaceBar` tidak cocok dibungkus kartu.

---

### Task 1: Font dan token warna

**Files:**
- Create: `photoquest_app/assets/fonts/MPLUSRounded1c-Regular.ttf`, `-Medium.ttf`, `-Bold.ttf`, `OFL.txt`
- Modify: `photoquest_app/pubspec.yaml` (blok `flutter:`)
- Create: `photoquest_app/lib/core/pq_colors.dart`
- Test: `photoquest_app/test/pq_theme_test.dart`

**Interfaces:**
- Produces:
  - `enum GlassTone { neutral, blue, yellow, red, green }`
  - `class GlassToneColors { final Color top, bottom, lip, edge, onColor; }`
  - `abstract final class PqPalette` berisi `blue`, `success`, `okay`, `warning`, `gold`, `orange`, `danger`, `blueTone`, `yellowTone`, `redTone`, `greenTone`, `tileRed`, `tileBlue`, `tileYellow`, `tilePurple`, `tileGreen`, `tileOrange`, dan `holo` (masing-masing `List<Color>`)
  - `class PqColors extends ThemeExtension<PqColors>` dengan field `bgBase`, `bgBlobs`, `text`, `heading`, `subtle`, `panel`, `panelEdge`, `neutral`, `holoInnerTop`, dan `holoInnerBottom`; method `tone(GlassTone)`; konstanta `PqColors.light` dan `PqColors.dark`; serta `static PqColors of(BuildContext)`

- [ ] **Step 1: Minta izin unduh font ke pengguna.**
  Sumber: `https://github.com/google/fonts/raw/main/ofl/mplusrounded1c/`. File yang diunduh: `MPLUSRounded1c-Regular.ttf`, `MPLUSRounded1c-Medium.ttf`, `MPLUSRounded1c-Bold.ttf`, dan `OFL.txt`. Ukuran sekitar 3 MB per file TTF karena memuat glyph Jepang. Tunggu jawaban "ya" sebelum lanjut.

- [ ] **Step 2: Unduh font.**

```bash
mkdir -p assets/fonts
for f in Regular Medium Bold; do curl -fL -o assets/fonts/MPLUSRounded1c-$f.ttf https://github.com/google/fonts/raw/main/ofl/mplusrounded1c/MPLUSRounded1c-$f.ttf; done
curl -fL -o assets/fonts/OFL.txt https://github.com/google/fonts/raw/main/ofl/mplusrounded1c/OFL.txt
ls -la assets/fonts
```

Expected: tiga file `.ttf` (masing-masing lebih dari 1 MB) dan `OFL.txt`.

- [ ] **Step 3: Kecilkan font jika `fonttools` tersedia** (opsional, untuk menghemat sekitar 9 MB APK).

```bash
python -c "import fontTools" && for f in Regular Medium Bold; do pyftsubset assets/fonts/MPLUSRounded1c-$f.ttf --unicodes="U+0000-024F,U+2000-206F,U+20AC,U+2190-21FF,U+2600-27BF" --output-file=assets/fonts/MPLUSRounded1c-$f.sub.ttf && mv assets/fonts/MPLUSRounded1c-$f.sub.ttf assets/fonts/MPLUSRounded1c-$f.ttf; done; ls -la assets/fonts
```

Kalau `python` atau `fontTools` tidak ada, lewati langkah ini dan catat untuk laporan tahap ("font tidak di-subset, APK bertambah sekitar 9 MB").

- [ ] **Step 4: Daftarkan font di `pubspec.yaml`.** Tambahkan tepat di bawah baris `uses-material-design: true`:

```yaml

  fonts:
    - family: MPLUSRounded1c
      fonts:
        - asset: assets/fonts/MPLUSRounded1c-Regular.ttf
          weight: 400
        - asset: assets/fonts/MPLUSRounded1c-Medium.ttf
          weight: 500
        - asset: assets/fonts/MPLUSRounded1c-Bold.ttf
          weight: 700
```

Lalu jalankan `flutter pub get`. Expected: tidak ada error.

- [ ] **Step 5: Tulis test yang gagal** di `test/pq_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/pq_colors.dart';

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
    expect(PqColors.light.tone(GlassTone.neutral), same(PqColors.light.neutral));
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
}
```

- [ ] **Step 6: Jalankan test untuk memastikan gagal.**
  Run: `flutter test test/pq_theme_test.dart`
  Expected: FAIL karena compile error `Target of URI doesn't exist: 'package:photoquest_app/core/pq_colors.dart'`.

- [ ] **Step 7: Tulis `lib/core/pq_colors.dart`:**

```dart
import 'package:flutter/material.dart';

/// Varian warna permukaan kaca (tombol, tile, pil).
enum GlassTone { neutral, blue, yellow, red, green }

/// Warna satu varian kaca: gradien atas-bawah, bibir 3D, tepi, dan teks di atasnya.
@immutable
class GlassToneColors {
  const GlassToneColors({
    required this.top,
    required this.bottom,
    required this.lip,
    required this.edge,
    required this.onColor,
  });

  final Color top;
  final Color bottom;
  final Color lip;
  final Color edge;
  final Color onColor;
}

/// Konstanta palet yang sama di mode terang dan gelap.
abstract final class PqPalette {
  static const blue = Color(0xFF36A6E6);
  static const success = Color(0xFF249653);
  static const okay = Color(0xFF6CB33F);
  static const warning = Color(0xFFE0A410);
  static const gold = Color(0xFFF5AA00);
  static const orange = Color(0xFFF27A32);
  static const danger = Color(0xFFCC3A33);

  static const blueTone = GlassToneColors(
    top: Color(0xB878D6FA),
    bottom: Color(0xAD36A6E6),
    lip: Color(0x802385C4),
    edge: Color(0xCCC8EEFF),
    onColor: Colors.white,
  );
  static const yellowTone = GlassToneColors(
    top: Color(0xC7FFE896),
    bottom: Color(0xADFFCB46),
    lip: Color(0x73D69E14),
    edge: Color(0xD9FFF5D2),
    onColor: Color(0xFF7A5A12),
  );
  static const redTone = GlassToneColors(
    top: Color(0xBFFF968C),
    bottom: Color(0xADF25B53),
    lip: Color(0x73CC3A33),
    edge: Color(0xD9FFD7D2),
    onColor: Colors.white,
  );
  static const greenTone = GlassToneColors(
    top: Color(0xBF8BEBAE),
    bottom: Color(0xAD38C371),
    lip: Color(0x73249653),
    edge: Color(0xD9D2FAE1),
    onColor: Colors.white,
  );

  static const tileRed = [Color(0xFFFF968C), Color(0xFFF25B53)];
  static const tileBlue = [Color(0xFF78D6FA), Color(0xFF36A6E6)];
  static const tileYellow = [Color(0xFFFFD95A), Color(0xFFF5AA00)];
  static const tilePurple = [Color(0xFFB9A8FF), Color(0xFF7B62E8)];
  static const tileGreen = [Color(0xFF8BEBAE), Color(0xFF38C371)];
  static const tileOrange = [Color(0xFFFFB083), Color(0xFFF27A32)];

  static const holo = [
    Color(0xD9FFE68C),
    Color(0xCCA6E8FF),
    Color(0xCCE7C2FF),
    Color(0xD9FFE68C),
  ];
}

/// Token warna PhotoQuest yang berbeda antara mode terang dan gelap.
@immutable
class PqColors extends ThemeExtension<PqColors> {
  const PqColors({
    required this.bgBase,
    required this.bgBlobs,
    required this.text,
    required this.heading,
    required this.subtle,
    required this.panel,
    required this.panelEdge,
    required this.neutral,
    required this.holoInnerTop,
    required this.holoInnerBottom,
  });

  final Color bgBase;
  final List<Color> bgBlobs;
  final Color text;
  final Color heading;
  final Color subtle;
  final Color panel;
  final Color panelEdge;
  final GlassToneColors neutral;
  final Color holoInnerTop;
  final Color holoInnerBottom;

  static const light = PqColors(
    bgBase: Color(0xFFF2F7FD),
    bgBlobs: [Color(0xFFC6E6FF), Color(0xFFFFE4BD), Color(0xFFDDD3FF)],
    text: Color(0xFF56627A),
    heading: Color(0xFF424E66),
    subtle: Color(0xFF8F9AB0),
    panel: Color(0x8CFFFFFF),
    panelEdge: Color(0xE6FFFFFF),
    neutral: GlassToneColors(
      top: Color(0x9EFFFFFF),
      bottom: Color(0x6BECF3FB),
      lip: Color(0x7396AED0),
      edge: Color(0xD9FFFFFF),
      onColor: Color(0xFF56627A),
    ),
    holoInnerTop: Color(0xF2FFFCF0),
    holoInnerBottom: Color(0xD9FFF3D2),
  );

  static const dark = PqColors(
    bgBase: Color(0xFF0F1729),
    bgBlobs: [Color(0xFF1E3A66), Color(0xFF3A2A55)],
    text: Color(0xFFB9C5DA),
    heading: Color(0xFFDCE5F4),
    subtle: Color(0xFF8796B3),
    panel: Color(0x7328385A),
    panelEdge: Color(0x1FFFFFFF),
    neutral: GlassToneColors(
      top: Color(0x7350648C),
      bottom: Color(0x59324469),
      lip: Color(0x800A101E),
      edge: Color(0x29FFFFFF),
      onColor: Color(0xFFB9C5DA),
    ),
    holoInnerTop: Color(0xCC2A3A5C),
    holoInnerBottom: Color(0xCC24334F),
  );

  /// Token dari theme aktif. Jika theme tidak memasang extension ini
  /// (misalnya MaterialApp polos di test), dipilih sesuai brightness.
  static PqColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PqColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  GlassToneColors tone(GlassTone tone) => switch (tone) {
    GlassTone.neutral => neutral,
    GlassTone.blue => PqPalette.blueTone,
    GlassTone.yellow => PqPalette.yellowTone,
    GlassTone.red => PqPalette.redTone,
    GlassTone.green => PqPalette.greenTone,
  };

  @override
  PqColors copyWith({
    Color? bgBase,
    List<Color>? bgBlobs,
    Color? text,
    Color? heading,
    Color? subtle,
    Color? panel,
    Color? panelEdge,
    GlassToneColors? neutral,
    Color? holoInnerTop,
    Color? holoInnerBottom,
  }) => PqColors(
    bgBase: bgBase ?? this.bgBase,
    bgBlobs: bgBlobs ?? this.bgBlobs,
    text: text ?? this.text,
    heading: heading ?? this.heading,
    subtle: subtle ?? this.subtle,
    panel: panel ?? this.panel,
    panelEdge: panelEdge ?? this.panelEdge,
    neutral: neutral ?? this.neutral,
    holoInnerTop: holoInnerTop ?? this.holoInnerTop,
    holoInnerBottom: holoInnerBottom ?? this.holoInnerBottom,
  );

  // Perpindahan terang-gelap cukup berganti di tengah animasi.
  @override
  PqColors lerp(covariant PqColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
```

- [ ] **Step 8: Jalankan test untuk memastikan lulus.**
  Run: `flutter test test/pq_theme_test.dart`
  Expected: PASS (4 test).

- [ ] **Step 9: Saran commit:** `feat(ui): font M PLUS Rounded 1c dan token warna PqColors`

---

### Task 2: GlassSurface dan GlassPressable

**Files:**
- Create: `photoquest_app/lib/ui/widgets/glass/glass_surface.dart`
- Create: `photoquest_app/lib/ui/widgets/glass/glass_pressable.dart`
- Test: `photoquest_app/test/glass_widgets_test.dart`

**Interfaces:**
- Consumes: `GlassToneColors`, `GlassTone`, dan `PqColors.of` dari Task 1.
- Produces:
  - `GlassSurface({required GlassToneColors tone, required Widget child, bool pressed = false, double radius = 16, bool haptic = false, bool dimmed = false})`, dengan konstanta `GlassSurface.lip` = 3.0
  - `const LinearGradient glassGloss`
  - `GlassPressable({required Widget child, VoidCallback? onTap, GlassTone tone = GlassTone.neutral, double radius = 16, EdgeInsetsGeometry padding = const EdgeInsets.all(12)})`
  - `Widget onColorTheme(BuildContext context, Color on, Widget child)`

- [ ] **Step 1: Tulis test yang gagal** di `test/glass_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/ui/widgets/glass/glass_pressable.dart';
import 'package:photoquest_app/ui/widgets/glass/glass_surface.dart';

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
}
```

Tambahkan juga import `package:photoquest_app/core/pq_colors.dart` di bagian atas file, karena `GlassTone` dipakai.

- [ ] **Step 2: Jalankan test untuk memastikan gagal.**
  Run: `flutter test test/glass_widgets_test.dart`
  Expected: FAIL karena compile error (file `glass_pressable.dart` belum ada).

- [ ] **Step 3: Tulis `lib/ui/widgets/glass/glass_surface.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pq_colors.dart';

/// Kilap kaca: putih tegas di separuh atas, terputus di tengah.
const glassGloss = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x6BFFFFFF),
    Color(0x1AFFFFFF),
    Color(0x00FFFFFF),
    Color(0x00FFFFFF),
  ],
  stops: [0, 0.48, 0.52, 1],
);

/// Permukaan kaca 3D: gradien semi-transparan, kilap, tepi tipis, dan bibir
/// di bawah. Saat [pressed], permukaan turun sedalam [lip] lalu memantul
/// kembali ketika dilepas.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.tone,
    required this.child,
    this.pressed = false,
    this.radius = 16,
    this.haptic = false,
    this.dimmed = false,
  });

  final GlassToneColors tone;
  final Widget child;
  final bool pressed;
  final double radius;

  /// Getar ringan setiap kali berubah menjadi ditekan.
  final bool haptic;

  /// Tampilan redup untuk tombol nonaktif.
  final bool dimmed;

  static const double lip = 3;
  static const pressDuration = Duration(milliseconds: 50);
  static const releaseDuration = Duration(milliseconds: 220);
  static const releaseCurve = Cubic(0.3, 1.8, 0.5, 1);

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  @override
  void didUpdateWidget(GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.haptic && widget.pressed && !oldWidget.pressed) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final radius = BorderRadius.circular(widget.radius);
    final surface = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.pressed ? 1 : 0),
      duration: widget.pressed
          ? GlassSurface.pressDuration
          : GlassSurface.releaseDuration,
      curve: widget.pressed ? Curves.easeOut : GlassSurface.releaseCurve,
      builder: (context, t, child) => CustomPaint(
        painter: _LipPainter(t: t, radius: widget.radius, lipColor: tone.lip),
        child: Transform.translate(
          offset: Offset(0, GlassSurface.lip * t),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: tone.edge),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone.top, tone.bottom],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, gradient: glassGloss),
          child: widget.child,
        ),
      ),
    );
    return widget.dimmed ? Opacity(opacity: 0.55, child: surface) : surface;
  }
}

/// Menggambar bibir 3D dan bayangan lembut hanya di luar muka tombol,
/// supaya warnanya tidak tembus ke kaca yang semi-transparan.
class _LipPainter extends CustomPainter {
  _LipPainter({required this.t, required this.radius, required this.lipColor});

  final double t;
  final double radius;
  final Color lipColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final face = RRect.fromRectAndRadius(
      Offset(0, GlassSurface.lip * t) & size,
      r,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addRect(Rect.fromLTWH(-24, -24, size.width + 48, size.height + 48)),
        Path()..addRRect(face),
      ),
    );
    final lift = (1 - t).clamp(0.0, 1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset(0, 4 + 2 * lift) & size, r),
      Paint()
        ..color = const Color(0x14284678)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 4 * lift),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Offset(0, GlassSurface.lip) & size, r),
      Paint()..color = lipColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LipPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.radius != radius ||
      oldDelegate.lipColor != lipColor;
}
```

- [ ] **Step 4: Tulis `lib/ui/widgets/glass/glass_pressable.dart`:**

```dart
import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Area kaca yang bisa ditekan: tile menu, jawaban kuis, kartu.
/// Jika [onTap] null, area tidak bereaksi tetapi tetap tampil normal.
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.tone = GlassTone.neutral,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final GlassTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tone = PqColors.of(context).tone(widget.tone);
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.tone != GlassTone.neutral) {
      content = onColorTheme(context, tone.onColor, content);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onTap,
        child: GlassSurface(
          tone: tone,
          radius: widget.radius,
          pressed: _down,
          haptic: true,
          child: content,
        ),
      ),
    );
  }
}

/// Tema teks dan ikon berwarna [on] untuk konten di atas permukaan berwarna.
Widget onColorTheme(BuildContext context, Color on, Widget child) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      textTheme: theme.textTheme.apply(bodyColor: on, displayColor: on),
      iconTheme: theme.iconTheme.copyWith(color: on),
      listTileTheme: theme.listTileTheme.copyWith(
        textColor: on,
        iconColor: on,
      ),
      dividerTheme: theme.dividerTheme.copyWith(
        color: on.withValues(alpha: 0.3),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: on),
      child: IconTheme.merge(data: IconThemeData(color: on), child: child),
    ),
  );
}
```

- [ ] **Step 5: Jalankan test untuk memastikan lulus.**
  Run: `flutter test test/glass_widgets_test.dart`
  Expected: PASS (4 test).

- [ ] **Step 6: Saran commit:** `feat(ui): GlassSurface dan GlassPressable dengan efek tekan 3D`

---

### Task 3: AppTheme lengkap

**Files:**
- Modify (ganti seluruh isi): `photoquest_app/lib/core/theme.dart`
- Test: `photoquest_app/test/pq_theme_test.dart` (tambah test)

**Interfaces:**
- Consumes: `PqColors`, `PqPalette`, dan `GlassToneColors` dari Task 1; `GlassSurface` dari Task 2.
- Produces: `AppTheme.light`, `AppTheme.dark`, dan `AppTheme.fontFamily` (`'MPLUSRounded1c'`). Nama getter tetap sama, jadi `main.dart` tidak perlu diubah.

- [ ] **Step 1: Tambah test yang gagal** di akhir `main()` pada `test/pq_theme_test.dart`. Tambahkan juga import `package:photoquest_app/core/theme.dart` dan `package:photoquest_app/ui/widgets/glass/glass_surface.dart`.

```dart
  test('AppTheme memasang PqColors dan font', () {
    expect(AppTheme.light.extension<PqColors>(), same(PqColors.light));
    expect(AppTheme.dark.extension<PqColors>(), same(PqColors.dark));
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
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
    await tester.pump(const Duration(milliseconds: 150));
    expect(dy(tester), 0);
    await gesture.up();
  });

  testWidgets('OutlinedButton bertema juga memakai GlassSurface', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(OutlinedButton(onPressed: () {}, child: const Text('Ulangi'))),
    );
    expect(find.byType(GlassSurface), findsOneWidget);
  });
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal.**
  Run: `flutter test test/pq_theme_test.dart`
  Expected: FAIL karena `AppTheme.fontFamily` belum ada (compile error).

- [ ] **Step 3: Ganti seluruh isi `lib/core/theme.dart`:**

```dart
import 'package:flutter/material.dart';

import '../ui/widgets/glass/glass_surface.dart';
import 'pq_colors.dart';

/// Tema "glassy TCG": tombol kaca 3D, panel frosted, teks abu-abu kebiruan.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'MPLUSRounded1c';

  static ThemeData get light => _build(PqColors.light, Brightness.light);

  static ThemeData get dark => _build(PqColors.dark, Brightness.dark);

  static ThemeData _build(PqColors c, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: PqPalette.blue,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? const Color(0xFF2E9BDB) : const Color(0xFF78D6FA),
          onPrimary: isLight ? Colors.white : const Color(0xFF0F1729),
          primaryContainer: isLight
              ? const Color(0xFFD9F1FD)
              : const Color(0xFF1E3A66),
          onPrimaryContainer: c.heading,
          secondary: PqPalette.gold,
          secondaryContainer: isLight
              ? const Color(0xFFFFF1C7)
              : const Color(0xFF4A3A10),
          onSecondaryContainer: c.heading,
          tertiary: PqPalette.success,
          tertiaryContainer: isLight
              ? const Color(0xFFDDF6E6)
              : const Color(0xFF1D4A31),
          onTertiaryContainer: c.heading,
          error: PqPalette.danger,
          surface: c.bgBase,
          onSurface: c.text,
          onSurfaceVariant: c.subtle,
          outline: c.subtle,
          surfaceContainerHigh: c.panel,
          surfaceContainerHighest: c.panel,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );
    final text = _textTheme(base.textTheme, c);
    final r16 = BorderRadius.circular(16);
    final overlayBg = isLight
        ? const Color(0xF2FFFFFF)
        : const Color(0xF21E2B45);
    const bold = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
    );
    const medium = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w500,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: c.bgBase,
      iconTheme: IconThemeData(color: c.text),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.heading,
        titleTextStyle: bold.copyWith(fontSize: 20, color: c.heading),
      ),
      cardTheme: CardThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.panelEdge),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _glassButton(PqPalette.blueTone),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _glassButton(c.neutral),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: bold.copyWith(fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.panel,
        selectedColor: PqPalette.yellowTone.top,
        side: BorderSide(color: c.panelEdge),
        shape: const StadiumBorder(),
        labelStyle: medium.copyWith(color: c.text),
        secondaryLabelStyle: medium.copyWith(color: PqPalette.yellowTone.onColor),
        checkmarkColor: PqPalette.yellowTone.onColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.panel,
        labelStyle: TextStyle(color: c.subtle),
        prefixIconColor: c.subtle,
        suffixIconColor: c.subtle,
        border: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: c.panelEdge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: c.panelEdge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: const BorderSide(color: PqPalette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: const BorderSide(color: PqPalette.danger, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: PqPalette.blueTone.bottom,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Colors.white : c.subtle,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? bold.copyWith(fontSize: 11, color: c.heading)
              : medium.copyWith(fontSize: 11, color: c.subtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xFF424E66)
            : const Color(0xFF28385A),
        contentTextStyle: medium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: r16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.panelEdge),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlayBg,
        modalBackgroundColor: overlayBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PqPalette.blue,
        linearTrackColor: c.panel,
        circularTrackColor: Colors.transparent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? PqPalette.blueTone.bottom
                : c.panel,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : c.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c.panelEdge)),
          textStyle: WidgetStatePropertyAll(bold.copyWith(fontSize: 13)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.subtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? PqPalette.blue : c.panel,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.panelEdge),
      ),
      listTileTheme: ListTileThemeData(textColor: c.text, iconColor: c.subtle),
      dividerTheme: DividerThemeData(color: c.subtle.withValues(alpha: 0.25)),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: c.subtle,
        indicatorColor: scheme.primary,
        dividerColor: Colors.transparent,
        labelStyle: bold.copyWith(fontSize: 14),
        unselectedLabelStyle: medium.copyWith(fontSize: 14),
      ),
    );
  }

  /// Judul 700 warna heading, isi 500 warna teks; tidak ada bobot 800 atau lebih.
  static TextTheme _textTheme(TextTheme t, PqColors c) {
    TextStyle? head(TextStyle? s) =>
        s?.copyWith(fontWeight: FontWeight.w700, color: c.heading);
    TextStyle? body(TextStyle? s) =>
        s?.copyWith(fontWeight: FontWeight.w500, color: c.text);
    return t.copyWith(
      displayLarge: head(t.displayLarge),
      displayMedium: head(t.displayMedium),
      displaySmall: head(t.displaySmall),
      headlineLarge: head(t.headlineLarge),
      headlineMedium: head(t.headlineMedium),
      headlineSmall: head(t.headlineSmall),
      titleLarge: head(t.titleLarge),
      titleMedium: head(t.titleMedium),
      titleSmall: head(t.titleSmall),
      bodyLarge: body(t.bodyLarge),
      bodyMedium: body(t.bodyMedium),
      bodySmall: body(t.bodySmall)?.copyWith(color: c.subtle),
      labelLarge: t.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
      labelMedium: body(t.labelMedium),
      labelSmall: body(t.labelSmall)?.copyWith(color: c.subtle),
    );
  }

  /// Tombol kaca 3D lewat backgroundBuilder: Material dibuat transparan,
  /// lalu GlassSurface menggambar kaca dan menggeser konten saat ditekan.
  static ButtonStyle _glassButton(GlassToneColors tone) => ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    splashFactory: NoSplash.splashFactory,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? tone.onColor.withValues(alpha: 0.6)
          : tone.onColor,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? tone.onColor.withValues(alpha: 0.6)
          : tone.onColor,
    ),
    backgroundBuilder: (context, states, child) => GlassSurface(
      tone: tone,
      pressed: states.contains(WidgetState.pressed),
      dimmed: states.contains(WidgetState.disabled),
      haptic: true,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
```

  Jika analyzer menolak `InputDecorationTheme` di `copyWith` (Flutter 3.47 bisa meminta `InputDecorationThemeData`), ganti nama kelasnya menjadi `InputDecorationThemeData` dengan field yang sama.

- [ ] **Step 4: Jalankan test untuk memastikan lulus.**
  Run: `flutter test test/pq_theme_test.dart`
  Expected: PASS (8 test).
  - Jika test "FilledButton bertema amblas" gagal karena `Transform` tidak ditemukan atau `dy` tetap 0, berarti `backgroundBuilder` tidak meneruskan state `pressed`. Pakai **fallback spec**: hapus `backgroundBuilder` dan beri gaya statis (`backgroundColor: tone.bottom`, `side: BorderSide(color: tone.edge)`). Di Task 5 dan 7–9, `FilledButton` utama (Masuk, Daftar, Coba lagi, Lanjut, Ulangi) diganti `GlassPressable(tone: GlassTone.blue, ...)` dengan teks yang sama.
  - **Laporkan ke pengguna jika fallback dipakai.**

- [ ] **Step 5: Jalankan seluruh test dan analyzer.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: analyze tanpa issue dan semua test lulus. Theme hanya dipakai `main.dart`, sedangkan test lama memakai `MaterialApp` polos.

- [ ] **Step 6: Saran commit:** `feat(ui): AppTheme glassy dengan tombol 3D bertema`

---

### Task 4: Komponen pendukung dan pratinjau golden

**Files:**
- Create: `lib/ui/widgets/glass/pq_background.dart`, `glass_panel.dart`, `glass_icon_tile.dart`, `glass_pill.dart`, `glass_progress_bar.dart`, `holo_card_frame.dart` (semua di `photoquest_app/`)
- Test: `photoquest_app/test/glass_widgets_test.dart` (tambah test)
- Create: `photoquest_app/test/ui_preview_test.dart`
- Modify: `photoquest_app/.gitignore` (tambah baris `test/preview/`)

**Interfaces:**
- Consumes: `PqColors`, `PqPalette`, `GlassTone`, `GlassSurface`, `glassGloss`, `GlassPressable`, dan `AppTheme`.
- Produces:
  - `PqBackground({required Widget child})`
  - `GlassPanel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), bool blur = false, double radius = 20})`
  - `GlassIconTile({required IconData icon, required List<Color> colors, double size = 44})`
  - `GlassPill({required String label, GlassTone tone = GlassTone.yellow, IconData? icon})`
  - `GlassProgressBar({required double value, List<Color> colors = PqPalette.tileBlue, double height = 12})`
  - `HoloCardFrame({required Widget child, VoidCallback? onTap})`

- [ ] **Step 1: Tambah test yang gagal** ke `test/glass_widgets_test.dart`. Tambahkan import untuk enam file baru ini dan `package:photoquest_app/core/theme.dart`.

```dart
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
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal.**
  Run: `flutter test test/glass_widgets_test.dart`
  Expected: FAIL karena compile error (file komponen belum ada).

- [ ] **Step 3: Tulis keenam komponen.**

`lib/ui/widgets/glass/pq_background.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';

/// Latar aplikasi: warna dasar dengan bercak warna radial yang lembut.
/// Dipakai sebagai PqBackground(child: Scaffold(backgroundColor: Colors.transparent)).
class PqBackground extends StatelessWidget {
  const PqBackground({super.key, required this.child});

  final Widget child;

  static const _centers = [
    Alignment(-0.8, -0.85),
    Alignment(0.9, -0.2),
    Alignment(-0.6, 0.8),
  ];

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bgBase)),
        for (var i = 0; i < c.bgBlobs.length && i < _centers.length; i++)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: _centers[i],
                  radius: 0.9,
                  colors: [c.bgBlobs[i], c.bgBlobs[i].withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
```

`lib/ui/widgets/glass/glass_panel.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';

/// Panel kaca frosted. [blur] memakai BackdropFilter, jadi pakai seperlunya
/// (bottom nav) karena berat di HP kelas bawah.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.blur = false,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: borderRadius,
        border: Border.all(color: c.panelEdge),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blur) return box;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: box,
      ),
    );
  }
}
```

`lib/ui/widgets/glass/glass_icon_tile.dart`:

```dart
import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// Tile ikon bergradien dengan kilap kaca (menu Home, ilustrasi state).
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 44,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0xB3FFFFFF)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, gradient: glassGloss),
        child: Icon(icon, size: size * 0.52, color: Colors.white),
      ),
    );
  }
}
```

`lib/ui/widgets/glass/glass_pill.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Lencana pil kaca (nomor soal, status, level). Tidak bisa ditekan.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.tone = GlassTone.yellow,
    this.icon,
  });

  final String label;
  final GlassTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = PqColors.of(context).tone(tone);
    return GlassSurface(
      tone: colors,
      radius: 999,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.onColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/ui/widgets/glass/glass_progress_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_surface.dart';

/// Bar progres berkilap. Nilai di luar 0..1 dijepit; NaN atau tak hingga = 0.
class GlassProgressBar extends StatelessWidget {
  const GlassProgressBar({
    super.key,
    required this.value,
    this.colors = PqPalette.tileBlue,
    this.height = 12,
  });

  final double value;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    final radius = BorderRadius.circular(999);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: radius,
          border: Border.all(color: c.panelEdge),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: glassGloss),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/ui/widgets/glass/holo_card_frame.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/pq_colors.dart';
import 'glass_pressable.dart';

/// Bingkai kartu koleksi: cincin gradien holo, isi krem, efek tekan 3D.
class HoloCardFrame extends StatelessWidget {
  const HoloCardFrame({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = PqColors.of(context);
    return GlassPressable(
      onTap: onTap,
      radius: 20,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: PqPalette.holo,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xE6FFFFFF)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.holoInnerTop, c.holoInnerBottom],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus.**
  Run: `flutter test test/glass_widgets_test.dart`
  Expected: PASS (8 test).

- [ ] **Step 5: Tulis pratinjau golden** di `test/ui_preview_test.dart`. Pratinjau ini hanya jalan jika flag `PQ_PREVIEW` diberikan, dan dipakai untuk melihat hasil secara visual.

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/pq_colors.dart';
import 'package:photoquest_app/core/theme.dart';
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
            Row(
              children: [
                const GlassPill(label: 'Soal 3 dari 10 · Skor 2'),
                const Spacer(),
                const GlassPill(label: 'Level 4', tone: GlassTone.blue),
              ],
            ),
            const SizedBox(height: 12),
            const GlassProgressBar(value: 0.3),
            const SizedBox(height: 16),
            Text('Halo, Si-ID', style: theme.textTheme.titleLarge),
            const Text('Siap berburu cahaya hari ini?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: const [
                GlassIconTile(icon: Icons.explore, colors: PqPalette.tileRed),
                GlassIconTile(icon: Icons.map, colors: PqPalette.tileBlue),
                GlassIconTile(icon: Icons.quiz, colors: PqPalette.tileYellow),
                GlassIconTile(icon: Icons.insights, colors: PqPalette.tilePurple),
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
            TextButton(onPressed: () {}, child: const Text('Belum punya akun? Daftar')),
            const SizedBox(height: 8),
            for (final tone in [GlassTone.yellow, GlassTone.green, GlassTone.red])
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
                ChoiceChip(label: const Text('Semua'), selected: true, onSelected: (_) {}),
                ChoiceChip(label: const Text('Jalanan'), selected: false, onSelected: (_) {}),
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
```

Tambahkan baris `test/preview/` di akhir `photoquest_app/.gitignore`.

- [ ] **Step 6: Buat dan lihat pratinjau.**
  Run: `flutter test test/ui_preview_test.dart --update-goldens --dart-define=PQ_PREVIEW=true`
  Expected: PASS, dan `test/preview/gallery_light.png` serta `gallery_dark.png` terbentuk.
  Buka kedua PNG (pakai tool Read) dan cek:
  - teks abu-abu kebiruan, bukan hitam;
  - tombol kaca semi-transparan dengan bibir tipis di bawah;
  - bibir tidak menodai isi tombol;
  - tombol nonaktif redup;
  - mode gelap terbaca.
  Perbaiki token jika ada yang jelek.

- [ ] **Step 7: Verifikasi penuh.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: tanpa issue. Semua test lulus; dua test pratinjau berstatus *skipped*.

- [ ] **Step 8: Saran commit:** `feat(ui): komponen kaca (panel, tile, pil, progres, kartu holo) dan pratinjau golden`

- [ ] **Step 9: STOP — akhir Tahap 1.** Kirim kedua PNG pratinjau ke pengguna dengan `SendUserFile`. Laporkan hasil analyze dan test, status subset font, dan apakah fallback tombol dipakai. Tunggu persetujuan sebelum Task 5.

---

### Task 5: Splash, login, register

**Files:**
- Modify: `lib/ui/screens/splash_screen.dart` (sekitar baris 97–137)
- Modify: `lib/ui/screens/login_screen.dart` (sekitar baris 58–141)
- Modify: `lib/ui/screens/register_screen.dart` (sekitar baris 63, dengan struktur serupa login)

**Interfaces:**
- Consumes: `PqBackground`, `GlassPanel`, `GlassIconTile`, dan `PqPalette.tileBlue`.

**Pola latar** (dipakai juga di Task 7–9) untuk layar yang dibuka sebagai route:

```dart
// sebelum
return Scaffold(
  appBar: ...,
  body: ...,
);
// sesudah
return PqBackground(
  child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: ...,
    body: ...,
  ),
);
```

Tambahkan import yang dibutuhkan, misalnya `import '../widgets/glass/pq_background.dart';`.

- [ ] **Step 1: Pastikan test terkait lulus sebelum diubah.**
  Run: `flutter test test/widget_test.dart`
  Expected: PASS. Ini baseline; test ini mengisi `TextFormField` di form login atau register.

- [ ] **Step 2: Ubah `splash_screen.dart`.**
  - Terapkan pola latar.
  - Ganti blok `Icon(Icons.camera_alt_rounded, size: 72, color: theme.colorScheme.primary)` dengan:

```dart
const GlassIconTile(
  icon: Icons.camera_alt_rounded,
  colors: PqPalette.tileBlue,
  size: 96,
),
```

  Tambahkan import `../widgets/glass/glass_icon_tile.dart` dan `../../core/pq_colors.dart`.

- [ ] **Step 3: Ubah `login_screen.dart`.**
  - Terapkan pola latar.
  - Ganti blok `Icon(Icons.camera_alt_rounded, size: 64, ...)` dengan `GlassIconTile(..., size: 80)` (warna `PqPalette.tileBlue`), lalu bungkus dengan `Center(...)` karena kolomnya memakai `CrossAxisAlignment.stretch`.
  - Bungkus widget `Form(...)` (anak dari `SingleChildScrollView`) dengan panel:

```dart
child: GlassPanel(
  padding: const EdgeInsets.all(20),
  child: Form(
    key: _formKey,
    child: Column(/* isi tidak berubah */),
  ),
),
```

- [ ] **Step 4: Ubah `register_screen.dart` dengan langkah yang sama seperti Step 3.**
  Gunakan pola latar, `GlassIconTile` untuk ikon kamera atau logo jika ada, dan `GlassPanel` yang membungkus `Form(...)`. Kalau struktur register berbeda (misalnya tanpa ikon), cukup terapkan pola latar dan `GlassPanel` di sekitar `Form`.

- [ ] **Step 5: Verifikasi.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: tanpa issue, semua test lulus.

- [ ] **Step 6: Saran commit:** `feat(ui): restyle splash, login, register`

- [ ] **Step 7: STOP — akhir Tahap 2.** Laporkan ke pengguna dan minta mereka mencoba di HP (`flutter run`), terutama efek tekan tombol Masuk. Tunggu persetujuan sebelum Task 6.

---

### Task 6: Skor kondisi untuk Home

**Files:**
- Create: `photoquest_app/lib/core/condition_score.dart`
- Test: `photoquest_app/test/condition_score_test.dart`

**Interfaces:**
- Consumes: `WeatherInfo`, `DayLight`, `TimeRange`, `HourlyPoint`, dan `CurrentWeather` dari `lib/data/models/weather_info.dart`. Konstruktor `HourlyPoint(time, cloudCover, precipitationProbability)` bersifat **posisional**, sedangkan `DayLight` memakai parameter bernama.
- Produces:
  - `class ConditionScore { final int score; final String label; }`
  - `double timingPoints(DateTime t, DayLight day)`
  - `double cloudPoints(num cloud)`
  - `double rainPoints(num rain)`
  - `String conditionLabel(int score)`
  - `ConditionScore? conditionScoreNow(WeatherInfo info, DateTime now)`

- [ ] **Step 1: Tulis test yang gagal** di `test/condition_score_test.dart`. Angka acuannya sama dengan `photoquest_api/test/score.test.js`.

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/core/condition_score.dart';
import 'package:photoquest_app/data/models/weather_info.dart';

DateTime at(String hhmm) => DateTime.parse('2026-10-10T$hhmm:00+07:00');

final day = DayLight(
  date: '2026-10-10',
  sunrise: at('05:21'),
  sunset: at('17:32'),
  goldenMorning: TimeRange(at('05:21'), at('06:21')),
  goldenEvening: TimeRange(at('16:32'), at('17:32')),
);

WeatherInfo info({
  List<HourlyPoint> hourly = const [],
  CurrentWeather? current,
  List<DayLight>? days,
}) => WeatherInfo(
  source: 'live',
  isEstimate: false,
  fetchedAt: at('12:00'),
  current: current,
  days: days ?? [day],
  hourly: hourly,
);

void main() {
  group('Timing cahaya (40), sama dengan backend', () {
    test('di dalam golden hour = 40', () {
      expect(timingPoints(at('17:00'), day), 40);
      expect(timingPoints(at('05:30'), day), 40);
    });

    test('turun linear: 1 jam = 30, 3 jam atau lebih = 10', () {
      expect(timingPoints(at('18:32'), day), 30);
      expect(timingPoints(at('20:32'), day), 10);
      expect(timingPoints(at('23:59'), day), 10);
    });

    test('tengah hari 11:00–14:00 WIB maksimal 10', () {
      expect(timingPoints(at('13:45'), day), 10);
    });
  });

  test('Tutupan awan (30), ideal lanskap 20–60%', () {
    expect(cloudPoints(40), 30);
    expect(cloudPoints(0), 20);
    expect(cloudPoints(80), 17.5);
    expect(cloudPoints(100), 5);
    expect(cloudPoints(150), 5); // dijepit ke 100
  });

  test('Peluang hujan (20) = 20 × (1 − hujan/100)', () {
    expect(rainPoints(0), 20);
    expect(rainPoints(50), 10);
    expect(rainPoints(100), 0);
  });

  test('Label sesuai batas 80/60/40', () {
    expect(conditionLabel(80), 'Sangat Baik');
    expect(conditionLabel(79), 'Baik');
    expect(conditionLabel(60), 'Baik');
    expect(conditionLabel(59), 'Cukup');
    expect(conditionLabel(40), 'Cukup');
    expect(conditionLabel(39), 'Kurang');
  });

  group('conditionScoreNow', () {
    test('kondisi ideal = 100 Sangat Baik', () {
      final s = conditionScoreNow(
        info(hourly: [HourlyPoint(at('17:00'), 40, 0)]),
        at('17:00'),
      )!;
      expect(s.score, 100);
      expect(s.label, 'Sangat Baik');
    });

    test('kondisi buruk: (10 + 5 + 2) / 90 = 19 Kurang', () {
      final s = conditionScoreNow(
        info(hourly: [HourlyPoint(at('12:30'), 100, 90)]),
        at('12:30'),
      )!;
      expect(s.score, 19);
      expect(s.label, 'Kurang');
    });

    test('tanpa prakiraan per jam: awan dari current, hujan default 20', () {
      final s = conditionScoreNow(
        info(
          current: CurrentWeather(
            time: at('17:00'),
            temperature: 27,
            cloudCover: 40,
            weatherCode: 2,
            description: 'Berawan',
          ),
        ),
        at('17:00'),
      )!;
      // 40 + 30 + 16 = 86 -> 86/90*100 = 95,6 -> 96
      expect(s.score, 96);
    });

    test('tanpa data cuaca sama sekali: awan 50, hujan 20 (default backend)', () {
      final s = conditionScoreNow(info(), at('17:00'))!;
      // 40 + 30 + 16 = 86 -> 96
      expect(s.score, 96);
    });

    test('tanpa data matahari hari ini -> null', () {
      expect(conditionScoreNow(info(days: const []), at('17:00')), isNull);
    });
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan gagal.**
  Run: `flutter test test/condition_score_test.dart`
  Expected: FAIL karena compile error (`condition_score.dart` belum ada).

- [ ] **Step 3: Tulis `lib/core/condition_score.dart`:**

```dart
import 'dart:math';

import '../data/models/weather_info.dart';

/// Skor kondisi memotret "sekarang" di lokasi pengguna, untuk kartu Home.
///
/// Porting dari Shoot Condition Score di backend
/// (photoquest_api/src/services/scoreService.js) tanpa komponen kecocokan
/// spot: timing 40 + awan 30 + hujan 20 = 90, lalu diskalakan ke 0–100.
/// Memakai aturan foto lanskap. Jika rumus backend berubah, ubah juga di sini.
class ConditionScore {
  const ConditionScore(this.score, this.label);

  final int score;
  final String label;
}

/// Sama dengan DEFAULT_CLOUD dan DEFAULT_RAIN di photoquest_api/src/routes/ai.js.
const defaultCloud = 50;
const defaultRain = 20;

double _round1(double v) => (v * 10).round() / 10;

/// Jam desimal WIB, mis. 16.5 = 16:30 WIB.
double _wibHour(DateTime t) {
  final w = t.toUtc().add(const Duration(hours: 7));
  return w.hour + w.minute / 60;
}

/// Jarak (jam) dari [t] ke rentang [r]; 0 jika di dalamnya.
double _hoursFromWindow(DateTime t, TimeRange r) {
  if (!t.isBefore(r.start) && !t.isAfter(r.end)) return 0;
  final gap = t.isBefore(r.start) ? r.start.difference(t) : t.difference(r.end);
  return gap.inMilliseconds / Duration.millisecondsPerHour;
}

/// Timing cahaya (maks 40): 40 di golden hour, turun linear sampai 10 saat
/// berjarak 3 jam atau lebih; 11:00–14:00 WIB maksimal 10.
double timingPoints(DateTime t, DayLight day) {
  final distance = min(
    _hoursFromWindow(t, day.goldenMorning),
    _hoursFromWindow(t, day.goldenEvening),
  );
  var score = 40 - 30 * (min(distance, 3.0) / 3);
  final hour = _wibHour(t);
  if (hour >= 11 && hour < 14 && score > 10) score = 10;
  return _round1(score);
}

/// Tutupan awan (maks 30), ideal lanskap 20–60%; awan 100% = 5.
double cloudPoints(num cloud) {
  final c = cloud.clamp(0, 100).toDouble();
  final double score;
  if (c < 20) {
    score = 20 + 10 * (c / 20);
  } else if (c <= 60) {
    score = 30;
  } else {
    score = 30 - 25 * ((c - 60) / 40);
  }
  return _round1(score);
}

/// Peluang hujan (maks 20) = 20 × (1 − hujan/100).
double rainPoints(num rain) =>
    _round1(20 * (1 - rain.clamp(0, 100).toDouble() / 100));

String conditionLabel(int score) {
  if (score >= 80) return 'Sangat Baik';
  if (score >= 60) return 'Baik';
  if (score >= 40) return 'Cukup';
  return 'Kurang';
}

/// Skor untuk [now] dari data cuaca yang sudah dimuat Home.
/// Null bila data matahari hari ini tidak ada.
ConditionScore? conditionScoreNow(WeatherInfo info, DateTime now) {
  final day = info.dayFor(now);
  if (day == null) return null;
  final hour = info.hourAt(now);
  final cloud = hour?.cloudCover ?? info.current?.cloudCover ?? defaultCloud;
  final rain = hour?.precipitationProbability ?? defaultRain;
  final total = timingPoints(now, day) + cloudPoints(cloud) + rainPoints(rain);
  final score = (total / 90 * 100).round();
  return ConditionScore(score, conditionLabel(score));
}
```

- [ ] **Step 4: Jalankan test untuk memastikan lulus.**
  Run: `flutter test test/condition_score_test.dart`
  Expected: PASS (11 test).
  Jika ada angka yang beda dari backend (misalnya pembulatan), samakan dengan perilaku JS: `Math.round` membulatkan x,5 ke atas, dan untuk bilangan positif hasilnya sama dengan `round()` di Dart. Jangan ubah angka acuannya.

- [ ] **Step 5: Saran commit:** `feat(home): skor kondisi berbasis lokasi (porting rumus backend)`

---

### Task 7: Shell, Home, Explore, dan kartu spot

**Files:**
- Modify: `lib/ui/screens/main_shell.dart` (seluruh `build`)
- Modify: `lib/ui/screens/home_tab.dart` (seluruh file)
- Modify: `lib/ui/widgets/weather_card.dart` (seluruh `build`)
- Modify: `lib/ui/widgets/spot_card.dart` (seluruh `build`)
- Modify: `lib/ui/widgets/spot_placeholder.dart` (`_colors` dan fallback)
- Modify: `lib/ui/screens/explore_screen.dart` (baris 55 Scaffold, baris 170 SpotCard)
- Modify: `lib/ui/screens/spot_detail_screen.dart` (baris 69 Scaffold, `SliverAppBar`)
- Modify: `lib/ui/screens/nearby_map_screen.dart` (baris 88 Scaffold, baris 183)
- Test: `test/glass_widgets_test.dart` (tambah test label menu panjang)

**Interfaces:**
- Consumes: `PqBackground`, `GlassPanel`, `GlassPressable`, `GlassIconTile`, `GlassPill`, `GlassSurface`, `HoloCardFrame`, `PqColors`, `PqPalette`, `GlassTone`, `onColorTheme` (tidak langsung, lewat `GlassPressable` bertone), dan `conditionScoreNow` dari Task 6.

- [ ] **Step 1: Tulis test yang gagal untuk label menu panjang.** `HomeTab` butuh provider, jadi yang dites adalah pola tile-nya.

```dart
  testWidgets('tile menu dengan label panjang tidak overflow', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 100,
          height: 100,
          child: GlassPressable(
            onTap: () {},
            padding: const EdgeInsets.all(8),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassIconTile(icon: Icons.straighten, colors: PqPalette.tileYellow, size: 40),
                SizedBox(height: 6),
                Text(
                  'Level & Stabilizer yang sangat panjang sekali',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
```

Run: `flutter test test/glass_widgets_test.dart`. Test ini sudah lulus jika `maxLines` dan `ellipsis` ada. Test ini mengunci pola yang dipakai di Step 3, jadi pola di Step 3 harus identik.

- [ ] **Step 2: Ganti `build` di `main_shell.dart`.** Tambahkan import `../widgets/glass/glass_panel.dart` dan `../widgets/glass/pq_background.dart`.

```dart
  @override
  Widget build(BuildContext context) {
    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index,
          children: const [HomeTab(), ProfileScreen(), FeedbackScreen()],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            blur: true,
            radius: 28,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.rate_review_outlined),
                  selectedIcon: Icon(Icons.rate_review),
                  label: 'Saran & Kesan',
                ),
                NavigationDestination(icon: Icon(Icons.logout), label: 'Logout'),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Ganti isi `home_tab.dart`.** Import tambahan: `../../core/pq_colors.dart`, `../widgets/glass/glass_icon_tile.dart`, dan `../widgets/glass/glass_pressable.dart`.
  - Ubah `_MenuItem` dan `_menu`:

```dart
class _MenuItem {
  const _MenuItem(this.label, this.icon, this.colors, this.builder);
  final String label;
  final IconData icon;
  final List<Color> colors;
  final WidgetBuilder builder;
}

final _menu = [
  _MenuItem('Explore', Icons.explore, PqPalette.tileRed, (_) => const ExploreScreen()),
  _MenuItem('Peta Terdekat', Icons.map, PqPalette.tileBlue, (_) => const NearbyMapScreen()),
  _MenuItem('Plan (AI)', Icons.insights, PqPalette.tilePurple, (_) => const PlanScreen()),
  _MenuItem('Assistant', Icons.chat_bubble, PqPalette.tileGreen, (_) => const AssistantScreen()),
  _MenuItem(
    'Level & Stabilizer',
    Icons.straighten,
    PqPalette.tileYellow,
    (_) => const LevelStabilizerScreen(),
  ),
  _MenuItem(
    'Steady Challenge',
    Icons.sports_esports,
    PqPalette.tileOrange,
    (_) => const SteadyChallengeScreen(),
  ),
  _MenuItem('PhotoQuiz', Icons.quiz, PqPalette.tilePurple, (_) => const QuizScreen()),
  _MenuItem(
    'Konverter',
    Icons.currency_exchange,
    PqPalette.tileGreen,
    (_) => const ConverterScreen(),
  ),
  _MenuItem('Chain Explorer', Icons.link, PqPalette.tileBlue, (_) => const ChainExplorerScreen()),
];
```

  - Di `GridView.count`, ubah `mainAxisSpacing` dan `crossAxisSpacing` menjadi `10`, lalu ganti `Card(...)` di dalam loop dengan:

```dart
for (final item in _menu)
  GlassPressable(
    onTap: () => _open(context, item),
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassIconTile(icon: item.icon, colors: item.colors, size: 40),
        const SizedBox(height: 6),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: PqColors.of(context).text,
          ),
        ),
      ],
    ),
  ),
```

  Bagian lain (`OfflineBanner`, header, `WeatherCard`, judul 'Menu') tetap sama.

- [ ] **Step 4: Ubah `weather_card.dart` menjadi hero biru dengan lencana skor.** Import `../../core/pq_colors.dart`, `../../core/condition_score.dart`, `glass/glass_pressable.dart`, `glass/glass_pill.dart`, dan `glass/glass_surface.dart`. Di `build`, ganti semua baris mulai dari `final result = weather.resultFor(lat, lng);` sampai akhir method (setelah `return Card(...)`) dengan blok di bawah. Konten sekarang dibangun di dalam `Builder`, supaya `Theme.of` membaca tema teks putih dari `GlassPressable`.

```dart
    final result = weather.resultFor(lat, lng);
    final error = weather.errorFor(lat, lng);
    final now = DateTime.now();

    return GlassPressable(
      tone: GlassTone.blue,
      radius: 20,
      padding: EdgeInsets.zero,
      onTap: result == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WeatherScreen(latitude: lat, longitude: lng),
              ),
            ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          if (result == null && error == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          if (result == null) {
            return ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Cuaca gagal dimuat'),
              subtitle: Text(error!),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => weather.load(lat, lng, force: true),
              ),
            );
          }
          final info = result.data;
          final today = info.dayFor(now);
          final current = info.current;
          final cond = conditionScoreNow(info, now);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_twilight, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current == null
                                ? 'Cuaca tidak tersedia'
                                : '${current.temperature.round()}°C · ${current.description}',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${current == null ? '' : 'Awan ${current.cloudCover}% · '}'
                            '${loc.isDemo || loc.position == null ? 'Lokasi demo' : 'Lokasi Anda'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (cond != null) _ScoreBadge(score: cond.score),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (cond != null) GlassPill(label: cond.label),
                    const Spacer(),
                    WeatherSourceChip(result: result),
                  ],
                ),
                if (today != null) ...[
                  const Divider(),
                  _goldenRow(
                    context,
                    'Golden hour pagi',
                    Formatters.rangeWib(
                      today.goldenMorning.start,
                      today.goldenMorning.end,
                    ),
                    goldenStatus(today.goldenMorning, now),
                  ),
                  _goldenRow(
                    context,
                    'Golden hour sore',
                    Formatters.rangeWib(
                      today.goldenEvening.start,
                      today.goldenEvening.end,
                    ),
                    goldenStatus(today.goldenEvening, now),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
```

  Hapus variabel lokal `theme` dan `content` lama yang kini tidak terpakai. `_goldenRow` tetap sama.

  Tambahkan widget privat ini di akhir `weather_card.dart`:

```dart
/// Lencana bulat kuning berisi skor kondisi (mis. "82 SKOR").
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    const tone = PqPalette.yellowTone;
    return Semantics(
      label: 'Skor kondisi $score',
      child: GlassSurface(
        tone: tone,
        radius: 32,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: tone.onColor,
                ),
              ),
              Text(
                'SKOR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: tone.onColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

  Teks diberi warna eksplisit `tone.onColor`, karena kartu ini berada di dalam tema teks putih milik hero biru.

- [ ] **Step 5: Ganti `build` di `spot_card.dart` dengan kartu holo.** Import `../../core/pq_colors.dart` dan `glass/holo_card_frame.dart`.

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoloCardFrame(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  spot.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? PqPalette.danger : theme.colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 110,
              child: SpotPlaceholder(category: spot.category, iconSize: 48),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${Labels.category(spot.category)} · ${Labels.bestTime(spot.bestTime)}',
            style: theme.textTheme.bodySmall,
          ),
          if (distanceKm != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.near_me, size: 14),
                const SizedBox(width: 4),
                Text(
                  Formatters.distance(distanceKm!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
```

- [ ] **Step 6: Ubah palet `spot_placeholder.dart`.**

```dart
  static const _colors = {
    'landscape': [Color(0xFFFFB36B), Color(0xFFFF6B4A)],
    'architecture': [Color(0xFFB9A8FF), Color(0xFF7B62E8)],
    'street': [Color(0xFF78D6FA), Color(0xFF36A6E6)],
    'nature': [Color(0xFF8BEBAE), Color(0xFF38C371)],
    'culture': [Color(0xFFFF968C), Color(0xFFF25B53)],
  };
```

Ganti fallback `const [Colors.grey, Colors.blueGrey]` menjadi `const [Color(0xFFB4C2D6), Color(0xFF8F9AB0)]`. Ubah juga arah gradien menjadi `begin: Alignment.topCenter, end: Alignment.bottomCenter`.

- [ ] **Step 7: Ubah `explore_screen.dart`.**
  - Terapkan pola latar pada `Scaffold` di baris 55.
  - Bungkus `SpotCard(...)` di baris 170 dengan `Padding(padding: const EdgeInsets.only(bottom: 12), child: SpotCard(...))`.

- [ ] **Step 8: Ubah `spot_detail_screen.dart`.**
  - Terapkan pola latar pada `Scaffold` di baris 69.
  - Di `SliverAppBar` (tempat `FlexibleSpaceBar` dengan `background: SpotPlaceholder` sekitar baris 81), tambahkan `backgroundColor: PqColors.of(context).bgBase,`. Ini perlu supaya saat appbar mengecil, judul tidak tertimpa konten di belakang appbar yang transparan. Import `../../core/pq_colors.dart`.

- [ ] **Step 9: Ubah `nearby_map_screen.dart`.**
  - Terapkan pola latar pada `Scaffold` di baris 88.
  - Ganti `Colors.blue` di baris 183 dengan `PqPalette.blue` (import `../../core/pq_colors.dart`). `Colors.white` di baris 169 tetap dipakai, karena itu tepi penanda di atas peta.

- [ ] **Step 10: Verifikasi.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: tanpa issue, semua test lulus. Perhatikan `main_shell_test`, `spot_test`, dan `weather_test`. Jika `weather_test` mencari `Card` atau `InkWell` di `WeatherCard`, **jangan ubah test**. Laporkan ke pengguna dan pertahankan perilakunya dengan cara lain.

- [ ] **Step 11: Saran commit:** `feat(ui): nav kaca melayang, menu tile, hero cuaca, kartu spot holo`

- [ ] **Step 12: STOP — akhir Tahap 3.** Laporkan ke pengguna dan minta mereka mencoba Home (termasuk lencana skor), Explore, dan nav di HP. Tunggu persetujuan sebelum Task 8.

---

### Task 8: Kuis, Steady Challenge, Level, dan widget skor/sensor

**Files:**
- Modify: `lib/ui/screens/quiz_screen.dart` (baris 44, 66–107, 128, 150–181)
- Modify: `lib/ui/screens/steady_challenge_screen.dart` (baris 127, 195, 251, 293, 295)
- Modify: `lib/ui/screens/level_stabilizer_screen.dart` (baris 21)
- Modify: `lib/ui/widgets/score_widgets.dart` (baris 7–10, 84–88)
- Modify: `lib/ui/widgets/sensor_widgets.dart` (baris 6, 7, 20, 21)

**Interfaces:**
- Consumes: `PqBackground`, `GlassPressable`, `GlassPill`, `GlassProgressBar`, `GlassTone`, dan `PqPalette`.

- [ ] **Step 1: Pastikan test terkait lulus sebelum diubah.**
  Run: `flutter test test/phase10_test.dart test/sensor_test.dart test/ai_test.dart`
  Expected: PASS. Ini baseline; teks 'Soal 1 dari 2', 'Benar!', 'Lanjut', dan 'Skor 1 / 2' harus tetap ada.

- [ ] **Step 2: Ubah `quiz_screen.dart`.** Import `../../core/pq_colors.dart`, `../widgets/glass/pq_background.dart`, `../widgets/glass/glass_pressable.dart`, `../widgets/glass/glass_pill.dart`, dan `../widgets/glass/glass_progress_bar.dart`.
  - Terapkan pola latar pada `Scaffold` di baris 44.
  - Di `_question`, ganti tiga widget pertama (`Text('Soal ...', labelLarge)`, `SizedBox(height: 8)`, `LinearProgressIndicator(...)`) dan `Text(q.question, ...)` dengan:

```dart
        Align(
          alignment: Alignment.centerLeft,
          child: GlassPill(
            label:
                'Soal ${s.index + 1} dari ${s.questions.length} · Skor ${s.score}',
          ),
        ),
        const SizedBox(height: 12),
        GlassProgressBar(value: (s.index + 1) / s.questions.length),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(q.question, style: theme.textTheme.titleLarge),
          ),
        ),
```

  - Di kartu penjelasan (baris 91–92), hapus baris `color: theme.colorScheme.secondaryContainer,`.
  - Di `_finished` (baris 128), ganti `color: Color(0xFFF9A825)` dengan `color: PqPalette.gold`.
  - Ganti seluruh `build` milik `_OptionButton`:

```dart
  @override
  Widget build(BuildContext context) {
    final (GlassTone tone, IconData? icon) = switch (state) {
      _OptionState.correct => (GlassTone.green, Icons.check),
      _OptionState.wrong => (GlassTone.red, Icons.close),
      _ => (GlassTone.neutral, null),
    };
    return GlassPressable(
      tone: tone,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (icon != null) Icon(icon),
        ],
      ),
    );
  }
```

  Variabel `theme` di `_question` tetap dipakai.

- [ ] **Step 3: Ubah `steady_challenge_screen.dart`.** Import `../../core/pq_colors.dart` dan `../widgets/glass/pq_background.dart`.
  - Terapkan pola latar pada `Scaffold` di baris 127.
  - Baris 195: `steady ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00)` menjadi `steady ? PqPalette.success : PqPalette.orange`.
  - Baris 251: `const Color(0xFFF9A825)` menjadi `PqPalette.gold`.
  - Baris 293: hapus `color: const Color(0xFFE8F5E9),` (panel kini diatur theme).
  - Baris 295: `Color(0xFF2E7D32)` menjadi `PqPalette.success`. Hapus `const` di depan `Icon` jika compiler mengeluh (`PqPalette.success` sendiri tetap const, jadi biasanya aman).

- [ ] **Step 4: Ubah `level_stabilizer_screen.dart`.**
  Terapkan pola latar pada `Scaffold` di baris 21 (yang ada di dalam pembungkus pada baris sebelumnya). Bungkus `Scaffold`-nya saja, bukan pembungkus luarnya.

- [ ] **Step 5: Ubah `score_widgets.dart`.** Import `../../core/pq_colors.dart` dan `glass/glass_progress_bar.dart`.

```dart
Color scoreColor(int score) {
  if (score >= 80) return PqPalette.success;
  if (score >= 60) return PqPalette.okay;
  if (score >= 40) return PqPalette.warning;
  return PqPalette.danger;
}
```

  Ganti `LinearProgressIndicator(value: c.score / c.max, minHeight: 8, borderRadius: ...)` (baris 84–88) dengan `GlassProgressBar(value: c.score / c.max, height: 10)`.

- [ ] **Step 6: Ubah `sensor_widgets.dart`.** Import `../../core/pq_colors.dart`.

```dart
const _levelColor = PqPalette.success; // hijau
const _tiltColor = PqPalette.orange; // oranye
```

  Ubah baris 20 menjadi `Stability.slightShake => PqPalette.warning, // kuning` dan baris 21 menjadi `Stability.shaky => PqPalette.danger, // merah`.

- [ ] **Step 7: Verifikasi.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: tanpa issue, semua test lulus (termasuk `phase10_test` dan `sensor_test`).

- [ ] **Step 8: Saran commit:** `feat(ui): restyle kuis, steady challenge, level, skor, sensor`

---

### Task 9: Layar fitur lainnya, avatar, state view

**Files:**
- Modify: `lib/ui/screens/weather_screen.dart` (baris 33)
- Modify: `lib/ui/screens/plan_screen.dart` (baris 243)
- Modify: `lib/ui/screens/assistant_screen.dart` (baris 125, 260–264)
- Modify: `lib/ui/screens/converter_screen.dart` (baris 31)
- Modify: `lib/ui/screens/chain_explorer_screen.dart` (baris 35, 128, 197, 216–217)
- Modify: `lib/ui/screens/profile_screen.dart` (baris 145, 245)
- Modify: `lib/ui/screens/feedback_screen.dart` (baris 86)
- Modify: `lib/ui/widgets/user_avatar.dart` (baris 62–68)
- Modify: `lib/ui/widgets/state_views.dart` (baris 31, 64)

**Interfaces:**
- Consumes: `PqBackground`, `GlassIconTile`, `PqColors`, dan `PqPalette`.

- [ ] **Step 1: Terapkan pola latar pada layar route:** weather (baris 33), plan (baris 243), assistant (baris 125), converter (baris 31, yaitu `Scaffold` di dalam `DefaultTabController`), dan chain_explorer (baris 35).

- [ ] **Step 2: Atur tab di dalam shell (profile baris 145, feedback baris 86).**
  Jangan bungkus dengan `PqBackground` karena latarnya sudah dari `MainShell`. Cukup tambahkan `backgroundColor: Colors.transparent,` ke `Scaffold` keduanya.

- [ ] **Step 3: Ganti warna langsung.** Import `../../core/pq_colors.dart` di file yang diubah.
  - `chain_explorer_screen.dart`:
    - Baris 128: `valid ? const Color(0xFF2E7D32) : const Color(0xFFC62828)` menjadi `valid ? PqPalette.success : PqPalette.danger`.
    - Baris 197: `Color(0xFFC62828)` menjadi `PqPalette.danger`.
    - Baris 216–217: `const Color(0xFF2E7D32)` menjadi `PqPalette.success`, dan `const Color(0xFFC62828)` menjadi `PqPalette.danger`.
  - `profile_screen.dart` baris 245: `Colors.green` menjadi `PqPalette.success`.

- [ ] **Step 4: Beri tepi kaca pada gelembung chat di `assistant_screen.dart`.**
  Di `BoxDecoration` gelembung (sekitar baris 260), tambahkan `border: Border.all(color: PqColors.of(context).panelEdge),` setelah `borderRadius`. Warnanya (`primaryContainer` atau `surfaceContainerHighest`) sudah dipetakan theme ke biru muda dan panel kaca.

- [ ] **Step 5: Ganti `build` di `user_avatar.dart`** (import `../../core/pq_colors.dart`):

```dart
  @override
  Widget build(BuildContext context) {
    final name = widget.user?.name.trim() ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PqPalette.yellowTone.edge, width: 2.5),
        boxShadow: [
          BoxShadow(color: PqPalette.yellowTone.lip, offset: const Offset(0, 3)),
        ],
      ),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: const Color(0xFFFFE896),
        foregroundColor: PqPalette.yellowTone.onColor,
        backgroundImage: _bytes == null ? null : MemoryImage(_bytes!),
        child: _bytes == null
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: widget.radius * 0.8,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
```

  `CircleAvatar` opak, jadi bayangan bibir di bawahnya tidak tembus.

- [ ] **Step 6: Ubah `state_views.dart`.** Import `../../core/pq_colors.dart` dan `glass/glass_icon_tile.dart`.
  - Baris 31 (`ErrorView`): `Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error)` menjadi `const GlassIconTile(icon: Icons.error_outline, colors: PqPalette.tileRed, size: 56)`. Hapus `final theme = Theme.of(context);` jika tidak terpakai lagi.
  - Baris 64 (`EmptyView`): `Icon(icon, size: 40, color: ...outline)` menjadi `GlassIconTile(icon: icon, colors: PqPalette.tileBlue, size: 56)`.

- [ ] **Step 7: Cek dialog dan bottom sheet.**
  `logout_dialog`, `biometric_offer`, `location_permission`, `spot_picker_sheet`, dan bottom sheet di plan dan profile otomatis mengikuti `dialogTheme` dan `bottomSheetTheme`, jadi tidak ada perubahan kode. Cek cepat dengan `grep -n "backgroundColor\|Color(" lib/ui/widgets/*dialog* lib/ui/widgets/biometric_offer.dart lib/ui/widgets/location_permission.dart lib/ui/widgets/spot_picker_sheet.dart`.
  Expected: tidak ada warna hard-coded yang melawan theme.

- [ ] **Step 8: Pastikan tidak ada warna Material lama yang tersisa.**
  Run: `grep -rnE "Color\(0xFF(2E7D32|C62828|F9A825|EF6C00|7CB342|E8F5E9|C8E6C9|FFCDD2)\)|Colors\.(red|green|blue)\b" lib/ui`
  Expected: tidak ada hasil.

- [ ] **Step 9: Verifikasi.**
  Run: `flutter analyze` lalu `flutter test`
  Expected: tanpa issue, semua test lulus (termasuk `profile_test`, `converter_test`, dan `ai_test`).

- [ ] **Step 10: Pratinjau ulang.**
  Run: `flutter test test/ui_preview_test.dart --update-goldens --dart-define=PQ_PREVIEW=true`
  Expected: PASS. Pastikan tidak ada regresi pada komponen.

- [ ] **Step 11: Saran commit:** `feat(ui): restyle layar fitur, avatar, dan state view`

- [ ] **Step 12: STOP — akhir Tahap 4 (selesai).**
  Laporkan ke pengguna: hasil analyze dan test, daftar file yang diubah, dan hal yang perlu dicek manual di HP (efek tekan dan haptic, blur nav, mode gelap, kelancaran scroll di daftar Explore). Sertakan saran pesan commit gabungan.

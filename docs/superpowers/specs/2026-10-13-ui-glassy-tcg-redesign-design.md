# Redesign UI PhotoQuest — Gaya "Glassy TCG"

Tanggal: 2026-10-13
Status: menunggu review pengguna

## 1. Tujuan

Mengubah tampilan dan rasa pakai aplikasi Flutter `photoquest_app` menjadi gaya
"TCG mobile glassy" (terinspirasi Pokemon TCG Pocket + referensi Dribbble), tanpa
mengubah fungsi, fitur, alur navigasi, maupun logika.

Acuan visual: prototipe HTML "glassy v2" yang disetujui di percakapan (tombol kaca
semi-transparan dengan bibir 3D tipis, panel frosted glass, teks abu-abu kebiruan).

### Kriteria sukses

- Semua 18 layar dan widget bersama memakai design system baru secara konsisten,
  di mode terang dan gelap.
- Tombol utama terasa "menonjol" dan memuaskan saat ditekan: turun 3 px, lalu
  memantul kembali, disertai haptic ringan.
- `flutter analyze` bersih dan semua test yang ada lulus tanpa mengubah test lama.
- Tidak ada perubahan di `lib/data`, `lib/providers`, `lib/services`, atau
  `photoquest_api`.

## 2. Batasan

- **Hanya UI, dengan satu pengecualian.** Yang boleh berubah: `lib/core/theme.dart`,
  `lib/core/pq_colors.dart` (baru), `lib/ui/**`, `pubspec.yaml` (hanya deklarasi
  font), dan aset font baru. Pengecualiannya adalah fitur skor kondisi di Home
  (bagian 5a), yang menambah `lib/core/condition_score.dart`. Keputusan ini diambil
  pengguna pada 2026-10-13.
- **Tanpa package baru.** Haptic memakai `flutter/services.dart`, efek kaca memakai
  `BackdropFilter` bawaan.
- **Tipe widget yang dipakai test dipertahankan:** `NavigationBar`, `ChoiceChip`,
  `TextFormField`, `TextField`, `ListView`. Widget ini di-restyle lewat theme, bukan
  diganti.
- Teks, label, ikon, dan urutan elemen yang dicari test tidak diubah.

## 3. Bahasa visual

### 3.1 Font

M PLUS Rounded 1c (lisensi OFL), dibundel di `photoquest_app/assets/fonts/`,
dengan tiga bobot: 400, 500, dan 700.

- Teks isi memakai bobot 500, judul dan angka memakai 700.
- Bobot 800 atau lebih tidak pernah dipakai.
- Ukuran mengikuti `TextTheme` Material 3 bawaan; hanya keluarga font dan bobotnya
  yang diganti.

### 3.2 Token warna (`ThemeExtension` bernama `PqColors`)

| Token | Terang | Gelap |
|---|---|---|
| bgBase | `#F2F7FD` | `#0F1729` |
| bgBlobs | `#C6E6FF`, `#FFE4BD`, `#DDD3FF` | `#1E3A66`, `#3A2A55` |
| text | `#56627A` | `#B9C5DA` |
| heading | `#424E66` | `#DCE5F4` |
| subtle | `#8F9AB0` | `#8796B3` |
| panel | putih 55% | `#28385A` 45% |
| panelEdge | putih 90% | putih 12% |

Varian tombol kaca. Setiap varian punya gradien atas dan bawah, warna bibir, tepi,
dan warna teks:

| Varian | Gradien (atas → bawah) | Bibir | Teks |
|---|---|---|---|
| neutral (terang) | putih 62% → `#ECF3FB` 42% | `#96AED0` 45% | text |
| neutral (gelap) | `#50648C` 45% → `#324469` 35% | `#0A101E` 50% | text |
| blue (utama) | `#78D6FA` 72% → `#36A6E6` 68% | `#2385C4` 50% | putih |
| yellow | `#FFE896` 78% → `#FFCB46` 68% | `#D69E14` 45% | `#7A5A12` |
| red | `#FF968C` 75% → `#F25B53` 68% | `#CC3A33` 45% | putih |
| green | `#8BEBAE` 75% → `#38C371` 68% | `#249653` 45% | putih |

Tepi tombol berupa garis 1 px versi sangat terang dari warnanya sendiri (putih 85%
untuk neutral; di gelap, putih 16%).

Warna tambahan untuk tile ikon: orange (`#FFB083` → `#F27A32`) dan purple
(`#B9A8FF` → `#7B62E8`). Warna bingkai holo: `#FFE68C`, `#A6E8FF`, `#E7C2FF`.

`ColorScheme` Material diturunkan dari token ini: primary = blue, secondary =
yellow, error = red, tertiary = green, surface = panel. Dengan begitu widget
Material yang belum dibungkus tetap serasi.

### 3.3 Geometri dan efek

- **Radius:** tombol 16, panel/kartu 20, tile ikon 13, pil 999.
- **Kilap kaca:** gradien putih dari 42% di atas ke 10% pada titik 48%, lalu
  terputus tegas menjadi transparan di 52%.
- **Bibir 3D:** bayangan solid 3 px ke bawah dengan warna bibir, ditambah bayangan
  lembut 0/6/12 dengan opasitas 8%.
- **Tekan:** turun 3 px dan bibir hilang dalam 50 ms. Saat dilepas, kembali dalam
  220 ms dengan kurva pantul `Cubic(0.3, 1.8, 0.5, 1)`. Haptic memakai
  `HapticFeedback.lightImpact()` saat ditekan.
- **Kinerja:** `BackdropFilter` (blur 12) hanya dipakai untuk bottom nav, bottom
  sheet, dialog, dan maksimal satu panel utama per layar. Tombol tidak memakai blur
  (cukup semi-transparan), supaya HP kelas bawah tetap lancar.
- **Latar:** warna dasar `bgBase` ditambah 2–3 bercak radial lembut (`bgBlobs`).

## 4. Arsitektur

Pendekatan: **theme dulu, widget kustom hanya di titik penting.**

1. **`lib/core/theme.dart`** berisi `AppTheme.light` dan `AppTheme.dark`, keduanya
   lengkap dengan:
   - Font dan `PqColors`.
   - `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, dan
     `iconButtonTheme`. Gaya kaca dan efek tekan 3D dipasang lewat
     `ButtonStyle.backgroundBuilder` yang membaca state `pressed`, sehingga 17
     `FilledButton` dan 12 `OutlinedButton` otomatis bergaya baru tanpa diganti
     tipenya. Pendekatan ini dibuktikan dulu di tahap 1. Jika
     `backgroundBuilder` tidak bisa menggeser konten dengan rapi, fallback-nya:
     tombol utama di layar diganti `GlassButton`, sedangkan theme hanya memberi
     gaya statis (tanpa efek turun).
   - `cardTheme`, `chipTheme`, `inputDecorationTheme`, `navigationBarTheme`,
     `appBarTheme` (transparan, tanpa elevasi), `snackBarTheme`, `dialogTheme`,
     `bottomSheetTheme`, `progressIndicatorTheme`, `segmentedButtonTheme`,
     `switchTheme`, dan `listTileTheme`.
   - `scaffoldBackgroundColor` = `bgBase` sebagai fallback aman.
2. **`lib/ui/widgets/glass/`** berisi komponen bersama. Satu file per komponen,
   masing-masing kecil dan bisa dites sendiri:
   - `pq_background.dart`: latar bercak. Dipakai sebagai
     `PqBackground(child: Scaffold(backgroundColor: Colors.transparent))`.
   - `glass_pressable.dart`: inti efek tekan 3D. Isinya `GestureDetector` dan
     `AnimatedContainer`, menerima `onTap`, varian, dan radius. Dipakai untuk tile,
     jawaban kuis, kartu yang bisa ditekan, dan tombol kustom.
   - `glass_button.dart`: tombol kaca dengan label dan ikon, dibangun di atas
     `glass_pressable`. Dipakai hanya di tempat yang butuh varian warna (misalnya
     tombol "Jawab" merah).
   - `glass_panel.dart`: panel frosted. Parameter `blur` default `false`.
   - `glass_icon_tile.dart`: tile ikon menu bergradien.
   - `glass_pill.dart`: lencana pil (misalnya "Soal 3/10" dan "Great shot").
   - `glass_progress_bar.dart`: bar progres berkilap.
   - `holo_card_frame.dart`: bingkai kartu koleksi bergradien holo untuk spot.
3. **Layar** hanya diubah di lapisan tampilan: membungkus dengan `PqScaffold`,
   mengganti `Card` dekoratif dengan `GlassPanel` atau `GlassPressable`, dan
   menyusun ulang tata letak bagian hero dan menu. Pemanggilan provider, callback,
   key, dan teks tetap sama.

## 5. Rancangan per layar

| Layar / widget | Perubahan |
|---|---|
| splash | Latar bercak, logo di dalam panel kaca, indikator progres bergaya baru |
| login, register | Form di dalam `GlassPanel`, input kaca dari theme, tombol utama blue |
| main_shell | `NavigationBar` dibuat melayang: panel kaca blur, tujuan aktif tampil sebagai pil blue |
| home_tab | Header sapaan dan avatar yellow, kartu hero blue (kondisi/golden hour dan lencana skor), grid menu `GlassIconTile` |
| explore | Daftar spot memakai `spot_card` baru, filter `ChoiceChip` dari theme |
| spot_card, spot_placeholder | `HoloCardFrame`: judul, skor, foto/placeholder, pil jenis spot, info jarak dan cuaca |
| spot_detail | Header `SliverAppBar` dengan placeholder berpalet baru (tanpa bingkai holo), info dalam panel, aksi memakai tombol kaca |
| nearby_map | Peta tetap; kontrol dan bottom sheet dibuat kaca |
| weather, weather_card | Panel kaca, angka besar bobot 700, ikon dalam tile |
| plan, spot_picker_sheet | Panel dan bottom sheet kaca |
| assistant | Gelembung chat sebagai panel kaca (pengguna blue, asisten neutral), input kaca |
| converter | Panel kaca, `SegmentedButton` dari theme |
| quiz | Pil nomor soal, bar progres, panel soal dengan pil kategori, jawaban `GlassPressable` (dipilih yellow; benar green; salah red) |
| steady_challenge, level_stabilizer, sensor_widgets | Panel timer, cincin level kaca dengan gelembung red, bar kestabilan green |
| score_widgets | Lencana skor bulat yellow dan bar komponen skor |
| chain_explorer | Blok sebagai panel kaca berurutan, warna valid/rusak memakai palet baru |
| profile, user_avatar | Header avatar yellow, kartu info kaca, tombol aksi |
| feedback | Form dalam panel kaca |
| state_views, logout_dialog, biometric_offer, location_permission | Ilustrasi ikon dalam tile, dialog dan tombol dari theme |

Warna yang ditulis langsung di layar (sekitar 30 tempat) diganti token `PqColors`
atau `ColorScheme`.

## 5a. Fitur tambahan: skor kondisi di Home

Kartu hero di Home menampilkan lencana bulat (contoh: "82 SKOR") dan pil label
("Sangat Baik", "Baik", "Cukup", atau "Kurang"), sesuai mockup.

- **Arti skor.** Skor ini menggambarkan seberapa bagus kondisi memotret di lokasi
  pengguna saat ini.
- **Lokasi.** Sama dengan kartu cuaca: posisi GPS terakhir, atau lokasi demo
  (Tugu Jogja) bila belum ada.
- **Rumus.** Porting dari `photoquest_api/src/services/scoreService.js`, memakai
  aturan foto lanskap, tanpa komponen kecocokan spot:
  - Timing cahaya, maksimal 40. Bernilai 40 di dalam golden hour, turun linear
    sampai 10 saat jaraknya 3 jam atau lebih. Pukul 11:00–14:00 WIB dibatasi
    maksimal 10.
  - Tutupan awan, maksimal 30. Ideal 20–60%.
  - Peluang hujan, maksimal 20, dihitung `20 × (1 − hujan/100)`.
  - Total maksimal 90 diskalakan ke 0–100 dan dibulatkan. Label memakai batas
    80, 60, dan 40.
- **Data.** Semua data berasal dari `WeatherInfo` yang sudah dimuat Home:
  - golden hour diambil dari `dayFor(now)`;
  - awan diambil dari `hourAt(now)`, lalu `current`, lalu default 50;
  - hujan diambil dari `hourAt(now)`, lalu default 20 (sama dengan default backend).
- **Tanpa jaringan tambahan dan tanpa AI.** Skor tetap muncul di mode offline atau
  estimasi.
- **Bila data hari ini tidak ada** (`dayFor(now)` null), lencana dan pil tidak
  ditampilkan.
- **Test.** Angka acuannya diambil dari `photoquest_api/test/score.test.js`, supaya
  hasil aplikasi dan backend konsisten.
- **Konsekuensi.** Rumus ada di dua tempat. Komentar di file Dart menunjuk ke file
  backend sebagai sumbernya.

## 5b. Fitur tambahan: pilihan tema di Profil

Disetujui pengguna pada 2026-10-13. Sebelumnya mode gelap sudah ada, tetapi hanya
mengikuti pengaturan sistem HP.

- **Tampilan.** Di kartu pengaturan Profil, di bawah "Login biometrik", ada baris
  "Tema tampilan" dengan `SegmentedButton` tiga pilihan: Sistem (default, sama
  dengan perilaku lama), Terang, dan Gelap.
- **Perilaku.** Tema berganti langsung tanpa restart. Pilihan disimpan di tabel
  `settings` dengan kunci `theme_mode`, berisi `system`, `light`, atau `dark`.
  Pilihan ini bertahan setelah aplikasi ditutup dan tidak terhapus saat logout.
- **Kode:**
  - `ThemeModeProvider` (ChangeNotifier). Penyimpanannya diinjeksi sebagai fungsi
    baca/tulis.
  - `main.dart` memuat provider sebelum `runApp`. Jika gagal, tema jatuh ke Sistem.
  - `MaterialApp.themeMode` membaca provider ini.
  - Widget `ThemeModeTile` hanya tampil jika provider tersedia, supaya test lama
    yang memasang Profil tanpa provider tetap lulus.
- **Cakupan berubah.** `lib/main.dart`, `lib/providers/theme_mode_provider.dart`,
  dan `lib/ui/widgets/theme_mode_tile.dart` kini masuk cakupan.

## 6. Tahapan implementasi

Berhenti dan lapor ke pengguna setelah setiap tahap.

1. **Fondasi.** Unduh dan daftarkan font, tulis `PqColors` dan theme lengkap, buat
   komponen di `widgets/glass/` beserta test widget `GlassPressable`.
2. **Autentikasi.** Splash, login, register.
3. **Shell dan penjelajahan.** Skor kondisi (bagian 5a), main_shell, home_tab,
   explore, spot_card, spot_placeholder, spot_detail, nearby_map.
4. **Fitur lainnya.** Quiz, steady_challenge, level_stabilizer, weather, plan,
   assistant, converter, chain_explorer, profile, feedback, serta widget yang
   tersisa.

## 7. Verifikasi

Setiap tahap:

- `flutter analyze` tanpa issue baru.
- `flutter test`: semua test lama lulus tanpa diedit.
- Test baru untuk `GlassPressable`: `onTap` terpanggil, offset turun saat ditekan,
  dan kembali ke 0 setelah dilepas.
- Jika emulator atau perangkat tersedia: jalankan aplikasi dan ambil screenshot
  layar yang berubah, di mode terang dan gelap.

## 8. Di luar cakupan

- Ikon launcher dan splash native Android.
- Animasi transisi antar-halaman kustom.
- Fitur baru, perubahan teks atau copy, dan perubahan backend.

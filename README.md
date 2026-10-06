# PhotoQuest

**Smart Photography Companion berbasis LBS, Sensor Smartphone, dan Artificial Intelligence.**
Tugas akhir mata kuliah Pemrograman Aplikasi Mobile.

Aplikasi pendamping fotografer pemula: menemukan spot foto di Yogyakarta dan spot terdekat,
melihat cuaca & jendela golden hour, mendapat skor kondisi pemotretan + rekomendasi AI,
bertanya ke asisten fotografi (LLM), alat bantu level & stabilitas dari sensor HP, serta
mini-game Steady Shot yang hasilnya dicatat di blockchain sederhana.

| Folder | Isi |
|---|---|
| `photoquest_app/` | Aplikasi Flutter (Android, minSdk 24) |
| `photoquest_api/` | Backend REST API (Node.js 22 + Express 5 + PostgreSQL) |
| `render.yaml`, `DEPLOY.md` | Konfigurasi & panduan deploy (Render + Neon) |

---

## Menjalankan secara lokal

### Backend
```bash
cd photoquest_api
npm install
cp .env.example .env      # isi DATABASE_URL, JWT_SECRET, (opsional) GEMINI_API_KEY & GEMINI_MODEL
npm run db:init           # buat tabel + data seed (MENGHAPUS data lama)
npm run dev               # server di port 3000, auto-restart saat file berubah
npm run llm:check         # (opsional) cek API key & model Gemini
```
Cek: `http://localhost:3000/health`. Akun demo hasil seed: `demo@photoquest.app` / `demo123`.

### Aplikasi di HP fisik
1. HP & laptop di Wi-Fi yang sama; cari IP laptop dengan `ipconfig` (IPv4 Address).
2. Aktifkan USB debugging di HP, sambungkan kabel, cek dengan `flutter devices`.
3. Jalankan:
   ```bash
   cd photoquest_app
   flutter run --dart-define=API_BASE_URL=http://IP-LAPTOP:3000
   ```
Tanpa `--dart-define`, aplikasi memakai `http://10.0.2.2:3000` (khusus emulator).
IP laptop bisa berubah setiap ganti jaringan; jika muncul "timeout 8 detik", cek IP lagi.

### Deploy & APK release
Lihat **[DEPLOY.md](DEPLOY.md)**.

---

## Pemetaan requirement

| # | Requirement | Implementasi | Lokasi utama |
|---|---|---|---|
| 1 | Konsep | Smart Photography Companion (bukan kamera/editor) | README ini |
| 2 | Login terenkripsi + session | bcrypt cost 10, JWT 7 hari, token di flutter_secure_storage (AES-GCM + Android Keystore), session dipulihkan di Splash, interceptor 401 → logout | `api/src/routes/auth.js`, `api/src/middleware/auth.js`, `app/lib/data/local/secure_store.dart`, `app/lib/ui/screens/splash_screen.dart` |
| 3 | Login biometrik | local_auth membuka session tersimpan; dialog aktivasi setelah login pertama; toggle di Profil | `app/lib/services/biometric_service.dart`, `app/lib/providers/auth_provider.dart` |
| 4 | DB lokal + online | sqflite (spots_cache, favorites_cache, quiz_questions, last_weather, settings) + PostgreSQL | `app/lib/data/local/db_helper.dart`, `api/sql/schema.sql` |
| 5 | Web service/API | REST API sendiri + Open-Meteo + Frankfurter + Gemini (via backend) | `api/src/routes/*`, `api/src/services/*` |
| 6 | LBS | geolocator, Haversine buatan sendiri, peta OSM (flutter_map), lokasi demo | `app/lib/core/geo_utils.dart`, `app/lib/ui/screens/nearby_map_screen.dart` |
| 7 | Bottom navigation | Home \| Profil (foto) \| Saran & Kesan \| Logout (dialog) | `app/lib/ui/screens/main_shell.dart` |
| 8 | Konversi mata uang (≥3) | IDR, USD, EUR, JPY untuk harga gear | `api/src/services/currencyService.js`, `app/lib/ui/screens/converter_screen.dart` |
| 9 | Konversi waktu | WIB, WITA, WIT, London (Europe/London, DST otomatis) | `app/lib/core/time_zones.dart` |
| 10 | Min. 2 sensor | Accelerometer (level/tilt, low-pass), Gyroscope (stabilitas, moving average) | `app/lib/core/sensor_math.dart`, `app/lib/providers/sensor_provider.dart` |
| 11 | AI | Shoot Condition Score rule-based (40/30/20/10) + rekomendasi terstruktur | `api/src/services/scoreService.js`, `api/src/services/recommendationService.js` |
| 12 | LLM | Photography Assistant (Gemini) dengan konteks spot & rencana | `api/src/services/llmService.js`, `api/src/routes/ai.js`, `app/lib/ui/screens/assistant_screen.dart` |
| 13 | Mini-game | Steady Shot Challenge + PhotoQuiz (offline) | `app/lib/core/steady_challenge.dart`, `app/lib/ui/screens/quiz_screen.dart` |
| 14 | Search & selection | Pencarian spot, filter kategori, pilih spot untuk Plan | `app/lib/ui/screens/explore_screen.dart`, `app/lib/ui/widgets/spot_picker_sheet.dart` |
| 15 | Notifikasi | Pengingat 30 menit sebelum rencana + uji 10 detik | `app/lib/services/notification_service.dart` |
| 16 | Blockchain sederhana | SHA-256 hash chain + proof-of-work, verifikasi (server & HP), demo tamper | `api/src/services/chainService.js`, `app/lib/ui/screens/chain_explorer_screen.dart` |

(`api/` = `photoquest_api/`, `app/` = `photoquest_app/`)

## Endpoint API

Format respons seragam: `{ success, data, message }`. Semua endpoint membutuhkan
`Authorization: Bearer <jwt>` kecuali `/health`, `/auth/register`, `/auth/login`.

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/health` | Status server & database |
| POST | `/auth/register`, `/auth/login` | Daftar / masuk → `{ token, user }` |
| GET | `/auth/me` | Validasi token |
| PUT | `/users/me` | Ubah nama |
| POST | `/users/me/photo` | Upload foto profil (multer, maks. 2 MB) |
| GET | `/users/:id/photo` | Ambil foto profil |
| GET | `/spots?search=&category=`, `/spots/:id` | Daftar/cari/filter spot, detail |
| GET/POST/DELETE | `/favorites`, `/favorites/:spotId` | Favorit |
| GET | `/weather?lat=&lng=` | Cuaca + golden hour (cache 30 menit, fallback estimasi) |
| POST | `/ai/score` | Skor kondisi + rekomendasi (AI / template) |
| POST | `/ai/chat` | Photography Assistant |
| GET/POST | `/sessions` | Sesi foto tersimpan |
| GET/POST | `/challenge` | Riwayat / kirim hasil Steady Challenge (sukses → blok baru) |
| GET | `/chain`, `/chain/verify` | Blok & verifikasi blockchain |
| POST | `/chain/tamper-demo`, `/chain/repair-demo` | Demo manipulasi (hanya `DEMO_MODE=true`) |
| GET | `/currency?base=IDR` | Kurs (cache 6 jam, fallback kurs tetap) |
| GET | `/gear` | Daftar gear fotografi |
| POST | `/feedback`, GET `/feedback/me` | Saran & Kesan mata kuliah |

## Pengujian otomatis
```bash
cd photoquest_api && npm test        # 85 tes (tanpa memanggil Gemini/Open-Meteo/Frankfurter asli)
cd photoquest_app && flutter test    # 74 tes unit & widget
cd photoquest_app && flutter analyze
```
Tes backend memakai database di `DATABASE_URL` (user uji dibuat lalu dihapus otomatis).

## Ketahanan (timeout & fallback)
| Layanan | Timeout | Fallback |
|---|---|---|
| Backend dari aplikasi | 8 dtk (AI: 20 dtk) | Data dari cache sqflite + banner "Mode offline" |
| Open-Meteo | 8 dtk | Cache memori → cache lama → estimasi sunrise 05.30 / sunset 17.45 WIB |
| Frankfurter | 8 dtk | Cache 6 jam → cache lama → kurs tetap (`source: "fallback"`) |
| Gemini | 8 dtk | Rekomendasi template per jenis foto; chat "Assistant sedang tidak tersedia, coba lagi" |
| GPS | 8 dtk | Posisi terakhir → lokasi demo Tugu Jogja |

## Keputusan teknis & penyimpangan dari spesifikasi awal
| Hal | Keputusan | Alasan |
|---|---|---|
| minSdk | 24 (bukan 23) | Batas minimum Flutter 3.47 |
| Foto profil | Tabel `user_photos` (bytea) + kolom `users.photo_url` | Disk server Render gratis hilang saat restart |
| `GET /challenge` | Ditambahkan | Profil wajib menampilkan riwayat challenge |
| Kurs | Diambil base EUR lalu kurs silang | Base IDR dari Frankfurter dibulatkan (galat ±0,5%) |
| Hash blockchain | JSON kanonik (key diurutkan) | JSONB PostgreSQL menyusun ulang urutan key |
| Skor awan "portrait" | Ideal 30–80% | Tidak diatur di spesifikasi; awan = cahaya lembut |
| Pengingat | Waktu rencana − 30 menit; ditolak jika < 30 menit lagi | Notifikasi ke waktu lampau tidak bermakna |
| Notifikasi | `inexactAllowWhileIdle` | Tanpa izin exact alarm; bisa tertunda sedikit |
| Chat | Field opsional `history` (10 pesan) | Agar asisten mengingat percakapan (tetap hanya di memori) |
| Explore | Chip filter "Favorit" | Tempat melihat daftar favorit |
| Status biometrik | Disimpan di secure storage (bukan sqflite) | Data keamanan |
| Golden hour | sunrise/sunset ± 60 menit | Penyederhanaan sesuai spesifikasi |

Koordinat spot (`-- TO_VERIFY` di `photoquest_api/sql/seed.sql`), harga tiket, dan harga gear
adalah **perkiraan** dan perlu dicek manual.

## Keamanan
- API key (Gemini) & rahasia JWT hanya di `photoquest_api/.env` / dashboard Render, tidak di aplikasi.
- `.env`, `android/key.properties`, dan `*.jks` ada di `.gitignore`.
- Password hanya disimpan sebagai hash bcrypt; query SQL selalu berparameter.

# Panduan Deploy PhotoQuest

Urutan: **(1) Database Neon → (2) Backend Render → (3) APK release**.
Semua layanan di bawah memakai paket gratis. Repo harus sudah di-push ke GitHub.

> Rahasia (password database, `GEMINI_API_KEY`, password keystore) **tidak pernah**
> ditulis di repo. Isi hanya di dashboard Render / file lokal yang di-`.gitignore`.

---

## 1. Database PostgreSQL di Neon

1. Daftar di <https://neon.tech> → **Create project** (region terdekat, mis. Singapore).
2. Di dashboard project → **Connect** → salin *connection string*, contoh:
   ```
   postgresql://neondb_owner:xxxx@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
   ```
3. Ubah bagian akhirnya menjadi `?sslmode=verify-full` (hapus `&channel_binding=require`):
   ```
   postgresql://neondb_owner:xxxx@ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=verify-full
   ```
   Driver `pg` versi yang dipakai memperlakukan `require` sama seperti `verify-full`
   (sertifikat diverifikasi) tetapi menampilkan peringatan; `verify-full` menghilangkan peringatan itu.
4. Isi tabel + data seed ke Neon **dari laptop** (sekali saja). Di PowerShell:
   ```powershell
   cd photoquest_api
   $env:DATABASE_URL="postgresql://...neon.tech/neondb?sslmode=verify-full"
   npm run db:init
   Remove-Item Env:DATABASE_URL
   ```
   Output yang benar: `Jumlah data: { users: '1', spots: '18', gear_items: '8' }`.
   (Variabel lingkungan menimpa nilai di `.env`, jadi `.env` lokal tidak perlu diubah.)

> ⚠️ `npm run db:init` **menghapus semua tabel** lalu membuat ulang. Jangan dijalankan lagi
> setelah ada data yang ingin disimpan.

## 2. Backend di Render

1. Daftar di <https://render.com> dengan akun GitHub.
2. **New → Blueprint** → pilih repo PhotoQuest. Render membaca `render.yaml` di root repo.
3. Render meminta nilai variabel yang bertanda `sync: false`:
   | Variabel | Isi |
   |---|---|
   | `DATABASE_URL` | connection string Neon dari langkah 1.3 |
   | `GEMINI_API_KEY` | API key dari Google AI Studio (boleh kosong → fitur AI memakai template) |

   `JWT_SECRET` dibuat acak otomatis. `GEMINI_MODEL`, `DEMO_MODE`, dll. sudah terisi
   dan bisa diubah di **Environment**.
4. **Apply** → tunggu build selesai (±2–4 menit). URL layanan berbentuk
   `https://photoquest-api.onrender.com` (nama bisa berbeda jika sudah dipakai orang lain).
5. Cek di browser: `https://<url-anda>/health` → harus berisi `"database":"connected"`.

### Penting: server gratis Render "tertidur"
Layanan gratis Render berhenti setelah ±15 menit tanpa request. Request pertama sesudahnya
butuh ±30–60 detik untuk membangunkan server, lebih lama dari timeout aplikasi (8 detik),
sehingga aplikasi menampilkan **Mode offline / timeout**.

**Sebelum demo:** buka `https://<url-anda>/health` di browser dan tunggu sampai JSON muncul,
baru buka aplikasi. Setelah itu respons normal (< 1 detik).

## 3. APK release

### 3a. Keystore (sekali saja, simpan baik-baik)
Dari folder `photoquest_app/android`:
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Lalu salin `android/key.properties.example` menjadi `android/key.properties` dan isi password-nya.
Kedua file (`*.jks`, `key.properties`) sudah di-`.gitignore`. **Jika keystore hilang, APK versi
berikutnya tidak bisa meng-update APK lama** (harus uninstall dulu).

Tanpa `key.properties`, build release tetap berhasil tetapi ditandatangani dengan debug key
(cukup untuk demo/tugas, tidak untuk Play Store).

### 3b. Build
Dari folder `photoquest_app`, arahkan ke URL Render (HTTPS):
```
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://<url-anda>
```
Hasil di `build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk` (±21 MB) → **pakai ini untuk HP Android modern**
- `app-armeabi-v7a-release.apk` (±19 MB) → HP lama 32-bit
- `app-x86_64-release.apk` → emulator

Tanpa `--split-per-abi` hasilnya satu APK universal (±58 MB) yang bisa dipasang di semua HP.

### 3c. Pasang di HP
- Lewat kabel: `flutter install --release` (HP terhubung, USB debugging aktif), atau
- Kirim file `.apk` ke HP (Drive/WhatsApp) → buka → izinkan "Instal dari sumber tidak dikenal".

> APK yang dibuild dengan URL Render tetap bisa dipakai di mana saja (tidak perlu satu Wi-Fi
> dengan laptop). APK yang dibuild dengan IP laptop (`http://192.168.x.x:3000`) hanya jalan
> saat HP & laptop satu jaringan dan `npm run dev` menyala.

## Checklist sebelum presentasi
- [ ] `https://<url-anda>/health` sudah dibuka & berisi `"database":"connected"` (server bangun)
- [ ] `GEMINI_API_KEY` terisi di Render → Plan menampilkan chip **AI (Gemini)**
- [ ] HP: izin lokasi, notifikasi, dan sidik jari/wajah sudah terdaftar
- [ ] HP: Setelan → Aplikasi → PhotoQuest → Baterai **Tanpa batasan** (notifikasi tepat waktu)
- [ ] Jika tidak di Yogyakarta: Peta Terdekat → aktifkan **lokasi demo**
- [ ] `DEMO_MODE=true` jika ingin menampilkan demo manipulasi blockchain

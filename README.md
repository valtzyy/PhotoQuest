# PhotoQuest

Smart Photography Companion berbasis LBS, sensor smartphone, dan Artificial Intelligence.
Tugas akhir mata kuliah Pemrograman Aplikasi Mobile.

| Folder | Isi |
|---|---|
| `photoquest_app/` | Aplikasi Flutter (Android) |
| `photoquest_api/` | Backend REST API (Node.js + Express + PostgreSQL) |

## Menjalankan backend (lokal)

```bash
cd photoquest_api
npm install
cp .env.example .env      # lalu isi DATABASE_URL dan JWT_SECRET
npm run db:init           # buat tabel + data seed (MENGHAPUS data lama)
npm run dev               # server di port 3000, auto-restart saat file berubah
```

Cek: buka `http://localhost:3000/health`.

Akun demo hasil seed: `demo@photoquest.app` / `demo123`.

## Menjalankan aplikasi di HP fisik

1. HP dan laptop harus berada di jaringan Wi-Fi yang sama.
2. Cari IP LAN laptop (`ipconfig` → IPv4 Address, mis. `192.168.0.199`).
3. Izinkan port 3000 di Windows Firewall (sekali saja).
4. Jalankan:

```bash
cd photoquest_app
flutter run --dart-define=API_BASE_URL=http://192.168.0.199:3000
```

Tanpa `--dart-define`, aplikasi memakai `http://10.0.2.2:3000` (khusus emulator Android).

## Keamanan

- Semua API key (Gemini, dll) hanya ada di `photoquest_api/.env`, tidak pernah di aplikasi Flutter.
- `.env` sudah masuk `.gitignore`; yang di-commit hanya `.env.example`.

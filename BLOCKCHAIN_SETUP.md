# Panduan Blockchain Sepolia

PhotoQuest mencatat hasil Steady Challenge yang **berhasil** ke blockchain publik
**Ethereum Sepolia testnet** (gratis, uang tidak nyata). Dokumen ini menjelaskan cara
menyiapkan wallet, ETH testnet, akses RPC, dan men-deploy smart contract.

> Aturan emas: wallet ini **khusus testnet**. Jangan pakai wallet yang berisi uang
> sungguhan, dan **jangan pernah** menempelkan private key atau seed phrase ke
> chat, repo Git, screenshot, atau laporan.

## 0. Kontrak yang dipakai

| Item | Nilai |
|---|---|
| Jaringan | Ethereum Sepolia (chain ID `11155111`) |
| Alamat kontrak | [`0x4787d938eb5FBf395020135C43ea1E8bE4419539`](https://sepolia.etherscan.io/address/0x4787d938eb5FBf395020135C43ea1E8bE4419539) |
| Pemilik / relayer | `0xdff6077D3505C12506d326d8d619647Ece0B0D52` |

| File | Fungsi |
|---|---|
| `photoquest_api/contracts/ChallengeRegistry.sol` | Smart contract (Solidity ^0.8.20) |
| `photoquest_api/contracts/ChallengeRegistry.abi.json` | ABI, dipakai backend (ethers.js) |
| `photoquest_api/contracts/ChallengeRegistry.bytecode.json` | Bytecode untuk `npm run chain:deploy` |

**Isi kontrak:** menyimpan daftar catatan `{attemptId, userId, holdSeconds×100,
avgTilt×1000, avgShake×1000, dataHash, timestamp}`. Fungsi tulis `record(...)` hanya
bisa dipanggil **pemilik** (wallet yang men-deploy = wallet relayer backend); alamat
lain ditolak dengan error `NotOwner`. Fungsi baca: `owner()`, `recordCount()`,
`getRecord(index)`. Setiap catatan memancarkan event `ChallengeRecorded` (terlihat di
Etherscan). `attemptId` (id baris `challenge_attempts`) membuat verifikasi dapat
mencocokkan baris database dengan catatan on-chain secara pasti; `dataHash` adalah
**keccak256** dari JSON kanonik data (hash bawaan Ethereum).

**Pengujian:** kontrak dikompilasi dengan solc 0.8.28 (tanpa peringatan) dan diuji di EVM
lokal: deploy, `record` oleh pemilik, isi `getRecord`, event, penolakan non-pemilik,
penolakan indeks di luar jangkauan, dan pencarian event per `attemptId`. Biaya gas
±140–160 ribu per catatan (pada Sepolia jauh di bawah 0,001 ETH testnet).

**Cara deploy:** Remix (editor di browser, bagian 4) atau dari laptop dengan
`npm run chain:deploy` (bagian 4B).

## 1. Buat wallet MetaMask khusus testnet

1. Pasang ekstensi **MetaMask** dari situs resmi <https://metamask.io/download/>
   (Chrome/Edge/Firefox). Pastikan URL-nya benar; banyak tiruan palsu.
2. Pilih **Create a new wallet**, buat password, lalu **catat Secret Recovery Phrase
   (12 kata) di kertas**. Simpan offline. Jangan difoto, jangan dikirim ke siapa pun.
3. Di bagian atas MetaMask klik pemilih jaringan, aktifkan **Show test networks**
   (atau cari "Sepolia"), lalu pilih **Sepolia**. (Chain ID: `11155111`.)
4. Salin **alamat wallet** Anda (diawali `0x…`, bisa dibagikan, tidak rahasia).

## 2. Ambil ETH Sepolia dari faucet

Anda butuh sekitar **0,05 ETH Sepolia** (cukup untuk deploy dan ratusan catatan).
Syarat faucet sering berubah; coba satu per satu sampai berhasil. Status per
23–24 Oktober 2026:

| Faucet | Catatan |
|---|---|
| Chainlink: <https://faucets.chain.link/sepolia> | **Gagal untuk ETH** bila wallet tidak memegang minimal 1 LINK di Ethereum mainnet (terbukti saat dicoba: ETH ditolak, hanya 25 LINK testnet yang berhasil, dan LINK tidak berguna untuk biaya transaksi). Lewati bila tidak punya LINK mainnet. |
| Google Cloud Web3: <https://cloud.google.com/application/web3/faucet/ethereum/sepolia> | Perlu login akun Google. Jumlah dan batas baru tampil setelah login. |
| PoW Faucet: <https://sepolia-faucet.pk910.de/> | **Coba ini dulu.** Tanpa akun dan tanpa saldo mainnet; klik Start Mining, biarkan tab terbuka sekitar 10–30 menit sampai reward ±0,05–0,1 ETH, lalu Stop Mining & Claim Rewards. |
| Alchemy: <https://www.alchemy.com/faucets/ethereum-sepolia> | 0,1 ETH per 24 jam, tetapi **mensyaratkan ≥ 0,001 ETH di Ethereum mainnet**. Lewati bila tidak punya. |

Cek saldo: buka <https://sepolia.etherscan.io/address/ALAMAT_WALLET_ANDA> atau lihat
di MetaMask (jaringan Sepolia). Bila saldo masih 0 setelah beberapa menit, coba faucet lain.

## 3. Dapatkan akses RPC (gratis)

Backend butuh URL RPC untuk berbicara dengan Sepolia. Pilih salah satu:

**A. Alchemy (disarankan untuk Render)**
1. Daftar gratis di <https://www.alchemy.com/>.
2. Buat app: **Create new app** → Chain: **Ethereum**, Network: **Sepolia**.
3. Buka app itu → salin **HTTPS endpoint** (bentuknya
   `https://eth-sepolia.g.alchemy.com/v2/<kunci-anda>`). URL ini mengandung kunci API,
   jadi **perlakukan sebagai rahasia** (akan menjadi `SEPOLIA_RPC_URL` di env).

**B. Infura**: alurnya sama di <https://www.infura.io/> (pilih Sepolia).

**C. RPC publik tanpa daftar (untuk coba-coba)**: `https://ethereum-sepolia-rpc.publicnode.com`.
Gratis dan tanpa kunci, tetapi dibatasi lajunya dan tanpa jaminan layanan. Cukup untuk
pengembangan, kurang ideal untuk demo presentasi.

## 4. Deploy kontrak lewat Remix

1. Buka <https://remix.ethereum.org/>.
2. Di panel **File explorer**, buat file baru `ChallengeRegistry.sol`, lalu tempel
   seluruh isi `photoquest_api/contracts/ChallengeRegistry.sol`.
3. Tab **Solidity compiler**: pilih compiler **0.8.28** (atau 0.8.x terbaru), klik
   **Compile ChallengeRegistry.sol**. Harus muncul tanda centang hijau tanpa error.
4. Tab **Deploy & run transactions**:
   - **Environment**: *Injected Provider – MetaMask*. MetaMask akan meminta izin
     menghubungkan akun; setujui.
   - Pastikan muncul **Sepolia (11155111)** dan akun yang benar.
   - **Contract**: `ChallengeRegistry`. Klik **Deploy** (constructor tidak punya parameter).
5. MetaMask menampilkan konfirmasi dengan biaya gas (dalam ETH Sepolia). Klik **Confirm**.
6. Tunggu 10–30 detik. Di panel bawah muncul transaksi sukses; di
   **Deployed Contracts** salin **alamat kontrak** (ikon salin).
7. Cek di <https://sepolia.etherscan.io/address/ALAMAT_KONTRAK>: harus ada transaksi
   "Contract Creation".
8. (Opsional, bagus untuk dosen) **Verifikasi kode di Etherscan** agar kodenya dapat
   dibaca publik: di halaman alamat kontrak → tab **Contract** → **Verify and Publish** →
   Compiler type *Solidity (Single file)*, versi **0.8.28**, License **MIT**, optimization
   sesuai Remix (bawaan Remix: **No**), tempel kode yang sama.
   Bila gagal, tidak masalah: fitur tetap berjalan.
9. Dengan Remix, buka kontrak yang ter-deploy → klik tombol **owner**: harus menampilkan
   alamat wallet Anda; **recordCount** harus `0`.

## 4B. Alternatif: deploy dari laptop (tanpa Remix)

Pakai cara ini bila Remix/MetaMask tidak menampilkan jaringan Sepolia. Yang dibutuhkan hanya
private key wallet yang sudah berisi ETH Sepolia (cara mengambilnya di bagian 5).

1. Isi `photoquest_api/.env` (file ini sudah di `.gitignore`):
   ```
   ETH_PRIVATE_KEY=0x...kunci-anda...
   ```
   `SEPOLIA_RPC_URL` boleh dikosongkan untuk deploy (skrip memakai RPC publik), tetapi tetap
   wajib diisi untuk backend.
2. Dari folder `photoquest_api`:
   ```
   npm run chain:deploy
   ```
   Skrip memeriksa bahwa RPC benar-benar Sepolia dan saldo > 0, lalu mencetak **alamat kontrak**,
   tautan Etherscan, dan pemilik kontrak (harus sama dengan alamat wallet Anda).
3. Salin alamat itu ke `.env`: `CHAIN_CONTRACT_ADDRESS=0x...`
4. Cek semuanya tanpa mengirim transaksi:
   ```
   npm run chain:status
   ```
   Hasil yang benar: jaringan `Sepolia OK`, saldo > 0, dan `Relayer = pemilik : YA`.

Kedua skrip tidak pernah mencetak private key maupun URL RPC. Bytecode yang di-deploy ada di
`contracts/ChallengeRegistry.bytecode.json` (solc 0.8.28, optimizer aktif 200 runs, EVM `paris`;
pakai pengaturan ini bila ingin verifikasi kode di Etherscan).

## 5. Siapkan private key untuk backend (relayer)

Backend perlu menandatangani transaksi atas nama wallet pemilik kontrak.
1. MetaMask → ikon titik tiga di akun → **Account details** → **Show private key**
   (masukkan password).
2. Simpan **sementara** di tempat aman (mis. catatan lokal yang tidak disinkronkan).
   Nanti dimasukkan **hanya** ke:
   - `photoquest_api/.env` (sudah di `.gitignore`) sebagai `ETH_PRIVATE_KEY=0x…`, dan
   - Environment Render (nilai rahasia, `sync: false`).
3. Jangan pernah membagikan private key (chat, repo, screenshot, laporan).

Variabel lingkungan yang dipakai backend (lihat juga `photoquest_api/.env.example`):

| Variabel | Isi | Rahasia? |
|---|---|---|
| `SEPOLIA_RPC_URL` | URL RPC dari langkah 3 | **Ya** (mengandung kunci API) |
| `ETH_PRIVATE_KEY` | Private key wallet testnet | **Ya, sangat** |
| `CHAIN_CONTRACT_ADDRESS` | Alamat kontrak dari langkah 4 | Tidak |

## 6. Cek hasil akhir

1. Dari `photoquest_api`: `npm run chain:status` harus menampilkan jaringan `Sepolia OK`,
   saldo > 0, dan `Relayer = pemilik : YA`.
2. Isi ketiga variabel di atas di Environment Render, lalu deploy ulang. Log Render harus
   menampilkan `Blockchain Sepolia: aktif (kontrak 0x…)`.
3. Menangkan Steady Challenge di aplikasi; di Chain Explorer status berubah dari
   "Menunggu konfirmasi" menjadi "Terkonfirmasi" dalam ±15–30 detik, dan tombol
   "Buka di Etherscan" menampilkan transaksinya.

## Pemecahan masalah

| Gejala | Penyebab / solusi |
|---|---|
| Remix tidak menampilkan akun / "Injected Provider" kosong | MetaMask terkunci atau ekstensi diblokir; buka MetaMask dan masukkan password, lalu muat ulang Remix. |
| MetaMask menampilkan jaringan lain (Ethereum Mainnet) | Ganti ke **Sepolia** sebelum Deploy. Jangan deploy di mainnet. |
| "Insufficient funds" saat Deploy | Saldo ETH Sepolia terlalu kecil; ambil dari faucet lain. |
| Faucet menolak ("sudah klaim" / "saldo mainnet kurang") | Tunggu 24 jam, coba faucet lain, atau pakai PoW Faucet. |
| Transaksi "pending" lama | Sepolia kadang lambat; tunggu beberapa menit. Jangan kirim ulang. |
| Remix gagal compile | Pastikan versi compiler ≥ 0.8.20 dan seluruh isi file ditempel tanpa terpotong. |

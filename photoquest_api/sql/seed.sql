-- =====================================================================
-- PhotoQuest - Data awal (seed)
-- Dijalankan setelah schema.sql lewat: npm run db:init
-- =====================================================================

-- ---------------------------------------------------------------------
-- User demo untuk uji login cepat
--   email    : demo@photoquest.app
--   password : demo123   (yang disimpan hanya hash bcrypt cost 10)
-- ---------------------------------------------------------------------
INSERT INTO users (name, email, password_hash) VALUES
  ('Demo User', 'demo@photoquest.app', '$2b$10$SOXarqQfmO3QBTW68vNfleobcae/rAXfWuI6Q6SjvOvimCV8ov/JS');

-- ---------------------------------------------------------------------
-- Spot foto di Yogyakarta (18 spot)
-- SEMUA koordinat adalah PERKIRAAN -> wajib dicek manual di OpenStreetMap / Google Maps.
-- entry_fee_idr juga PERKIRAAN (harga tiket dewasa domestik), NULL = gratis/tidak pasti.
-- image_url sengaja NULL: aplikasi menampilkan placeholder per kategori.
-- ---------------------------------------------------------------------
INSERT INTO spots (name, category, description, latitude, longitude, best_time, photo_types, tips, entry_fee_idr) VALUES
('Tugu Jogja', 'architecture',
 'Monumen ikonik di persimpangan Jl. Jenderal Sudirman dan Jl. Margo Utomo, simbol garis imajiner Merapi - Keraton - Laut Selatan.',
 -7.7829, 110.3671, -- TO_VERIFY
 'sunrise', ARRAY['architecture','street','portrait'],
 'Datang sebelum jam 06.00 agar lalu lintas masih sepi. Gunakan sudut rendah agar tugu tampak megah terhadap langit.', NULL),

('Jalan Malioboro', 'street',
 'Jalan legendaris pusat belanja dan budaya Jogja, ramai pedagang, andong, dan pejalan kaki.',
 -7.7926, 110.3658, -- TO_VERIFY
 'any', ARRAY['street','portrait'],
 'Cari momen human interest: becak, andong, pedagang. Malam hari lampu jalan cocok untuk foto suasana.', NULL),

('Keraton Yogyakarta', 'culture',
 'Istana resmi Kesultanan Ngayogyakarta Hadiningrat dengan arsitektur Jawa klasik dan pendopo-pendopo bersejarah.',
 -7.8053, 110.3642, -- TO_VERIFY
 'any', ARRAY['architecture','portrait'],
 'Perhatikan aturan memotret di area dalam. Fokus pada detail ornamen, pilar, dan abdi dalem (minta izin).', 15000),

('Taman Sari', 'architecture',
 'Bekas taman istana Kesultanan dengan kolam pemandian, lorong bawah tanah, dan Sumur Gumuling.',
 -7.8100, 110.3594, -- TO_VERIFY
 'any', ARRAY['architecture','portrait'],
 'Sumur Gumuling paling bagus saat cahaya matahari masuk dari atas (sekitar tengah hari). Datang pagi agar tidak ramai.', 15000),

('Candi Prambanan', 'culture',
 'Kompleks candi Hindu terbesar di Indonesia, situs Warisan Dunia UNESCO.',
 -7.7520, 110.4915, -- TO_VERIFY
 'sunset', ARRAY['architecture','landscape','sunset','portrait'],
 'Siluet candi saat matahari terbenam sangat dramatis. Gunakan lensa lebar untuk keseluruhan kompleks.', 50000),

('Candi Ratu Boko', 'landscape',
 'Situs purbakala di atas bukit dengan gerbang ikonik, terkenal sebagai spot sunset dengan latar Prambanan.',
 -7.7705, 110.4894, -- TO_VERIFY
 'sunset', ARRAY['sunset','landscape','architecture'],
 'Bingkai matahari terbenam di dalam gerbang utama. Bawa tripod untuk eksposur setelah matahari tenggelam.', 40000),

('Bukit Bintang', 'landscape',
 'Tepi jalan Jogja-Wonosari di Patuk dengan pemandangan lampu kota Jogja dari ketinggian.',
 -7.8433, 110.4777, -- TO_VERIFY
 'sunset', ARRAY['landscape','sunset'],
 'Blue hour setelah sunset adalah waktu terbaik untuk city lights. Wajib tripod dan shutter lambat.', NULL),

('Pantai Parangtritis', 'landscape',
 'Pantai selatan paling terkenal di Jogja dengan ombak besar dan bentang pasir luas.',
 -8.0255, 110.3290, -- TO_VERIFY
 'sunset', ARRAY['sunset','landscape','portrait'],
 'Pantulan langit sunset di pasir basah membuat foto lebih dramatis. Lindungi kamera dari cipratan air laut.', 10000),

('Gumuk Pasir Parangkusumo', 'nature',
 'Bukit pasir pantai yang langka di Asia Tenggara, tekstur pasirnya bagus untuk foto minimalis.',
 -8.0179, 110.3196, -- TO_VERIFY
 'sunrise', ARRAY['landscape','portrait'],
 'Cahaya pagi yang rendah memunculkan tekstur dan bayangan riak pasir. Hindari siang hari karena terlalu terik.', 5000),

('Kalibiru', 'nature',
 'Wisata alam di perbukitan Menoreh, Kulon Progo, dengan panggung kayu di atas pohon menghadap Waduk Sermo.',
 -7.8060, 110.1290, -- TO_VERIFY
 'sunrise', ARRAY['landscape','portrait'],
 'Pagi hari sering berkabut tipis di atas waduk. Gunakan foto wide agar waduk dan perbukitan masuk frame.', 15000),

('Hutan Pinus Mangunan', 'nature',
 'Hutan pinus di Dlingo, Bantul, dengan cahaya matahari yang menembus sela pepohonan.',
 -7.9266, 110.4317, -- TO_VERIFY
 'sunrise', ARRAY['landscape','portrait'],
 'Cari sinar matahari pagi yang menembus kabut (light rays). Underexpose sedikit agar berkas cahaya terlihat.', 5000),

('Kebun Buah Mangunan', 'landscape',
 'Bukit dengan gardu pandang menghadap lembah Sungai Oya, terkenal dengan pemandangan negeri di atas awan.',
 -7.9417, 110.4245, -- TO_VERIFY
 'sunrise', ARRAY['landscape'],
 'Datang sebelum subuh untuk menangkap lautan kabut. Gunakan lensa tele untuk memampatkan lapisan bukit.', 10000),

('Puncak Becici', 'landscape',
 'Hutan pinus dan gardu pandang di Dlingo dengan panorama perbukitan dan kota Jogja.',
 -7.9020, 110.4370, -- TO_VERIFY
 'sunset', ARRAY['landscape','sunset','portrait'],
 'Siluet pohon pinus dan orang di gardu pandang saat golden hour sore sangat fotogenik.', 5000),

('Tebing Breksi', 'landscape',
 'Bekas tambang batu breksi yang dipahat menjadi tebing berukir dan amfiteater terbuka.',
 -7.7820, 110.5048, -- TO_VERIFY
 'sunset', ARRAY['landscape','sunset','architecture','portrait'],
 'Naik ke puncak tebing saat sore untuk melihat sunset dengan latar Candi Prambanan dan Gunung Merapi.', 10000),

('Alun-Alun Kidul', 'street',
 'Alun-alun selatan Keraton dengan dua pohon beringin kembar dan odong-odong berlampu di malam hari.',
 -7.8118, 110.3633, -- TO_VERIFY
 'sunset', ARRAY['street','portrait'],
 'Malam hari coba teknik light trail dari odong-odong berlampu dengan shutter 1-4 detik di atas tripod.', NULL),

('Kotagede', 'culture',
 'Kawasan kota tua bekas ibu kota Mataram Islam, terkenal dengan gang sempit, rumah kalang, dan kerajinan perak.',
 -7.8290, 110.3990, -- TO_VERIFY
 'any', ARRAY['street','architecture','portrait'],
 'Jelajahi gang-gang sempit untuk leading lines. Perajin perak cocok untuk foto human interest (minta izin).', NULL),

('Jembatan Kewek', 'street',
 'Jembatan rel kereta tua bergaya kolonial di atas Jl. Abu Bakar Ali, dekat Stasiun Tugu.',
 -7.7888, 110.3686, -- TO_VERIFY
 'any', ARRAY['street','architecture'],
 'Tunggu kereta melintas di atas jembatan untuk foto yang lebih bercerita. Perhatikan lalu lintas saat memotret.', NULL),

('Titik Nol Kilometer', 'architecture',
 'Kawasan perempatan bersejarah dengan bangunan kolonial seperti Gedung BNI dan Kantor Pos Besar.',
 -7.8013, 110.3647, -- TO_VERIFY
 'any', ARRAY['architecture','street','portrait'],
 'Blue hour membuat bangunan kolonial yang menyala tampak kontras dengan langit. Jaga garis vertikal tetap lurus.', NULL);

-- ---------------------------------------------------------------------
-- Gear fotografi untuk Konverter Mata Uang (harga PERKIRAAN pasar Indonesia)
-- ---------------------------------------------------------------------
INSERT INTO gear_items (name, price_idr) VALUES
  ('Tripod aluminium', 450000),
  ('Lensa prime 50mm f/1.8', 2500000),
  ('Filter ND variabel 67mm', 350000),
  ('Filter CPL 67mm', 300000),
  ('Gimbal smartphone 3-axis', 1500000),
  ('Remote shutter Bluetooth', 75000),
  ('Memory card SD 64GB', 200000),
  ('Tas kamera sling', 400000);

// Foto asli spot dari Wikimedia Commons (lisensi bebas CC BY-SA).
// Format: [nama spot, nama file di Commons, pembuat foto, lisensi].
// Atribusi (pembuat + lisensi) disimpan di kolom spots.image_credit dan ditampilkan di aplikasi.
const SPOT_IMAGES = [
  ["Tugu Jogja", "Yogyakarta Indonesia Tugu-Yogyakarta-01.jpg", "CEphoto, Uwe Aranas", "CC BY-SA 3.0"],
  ["Jalan Malioboro", "Malioboro Street, Yogyakarta.JPG", "Gunawan Kartapranata", "CC BY-SA 3.0"],
  ["Keraton Yogyakarta", "Yogyakarta Indonesia Kraton-the-Sultans-Palace-02.jpg", "CEphoto, Uwe Aranas", "CC BY-SA 3.0"],
  ["Taman Sari", "Indonesia - Java - Yogyakarta - Taman Sari.jpg", "Nanterjen", "CC BY-SA 4.0"],
  ["Candi Prambanan", "Yogyakarta Indonesia Prambanan-temple-complex-02.jpg", "CEphoto, Uwe Aranas", "CC BY-SA 3.0"],
  ["Candi Ratu Boko", "Kraton Ratu Boko (Ratu Boko Temple) in Yogyakarta, Indonesia 03.jpg", "M Yusril Mirza", "CC BY-SA 4.0"],
  ["Bukit Bintang", "Sunset view on the road near Bukit Bintang, Patuk, Gunungkidul (1).jpg", "Alharomain354", "CC BY-SA 4.0"],
  ["Pantai Parangtritis", "Dusk till dawn (cropped).jpg", "Cecee ch", "CC BY-SA 4.0"],
  ["Gumuk Pasir Parangkusumo", "Gumuk Pasir Parangkusumo 2.jpg", "Elvinamonica", "CC BY-SA 4.0"],
  ["Kalibiru", "Kalibiru, Bluriver.jpg", "Jovian Lukito", "CC BY-SA 4.0"],
  ["Hutan Pinus Mangunan", "Hutan Pinus Mangunan (1).jpg", "Nefrit Lazurit", "CC BY-SA 4.0"],
  ["Kebun Buah Mangunan", "Kebun Buah Mangunan.jpg", "Erlyndita Setyawardani", "CC BY-SA 4.0"],
  ["Puncak Becici", "Puncak Pinus Becici.jpg", "Fandy Aprianto Rohman", "CC BY-SA 4.0"],
  ["Tebing Breksi", "Lahan parkir dan amfiteater di Tebing Breksi Yogyakarta.jpg", "Ardhan Febriansyah", "CC BY-SA 4.0"],
  ["Alun-Alun Kidul", "Evening atmosphere at Alun-alun Kidul, Yogyakarta (2021).jpg", "Sam Hidayat", "CC BY-SA 4.0"],
  ["Kotagede", "Kota Gede Jogjakarta.jpg", "Gunawan Kartapranata", "CC BY-SA 3.0"],
  ["Jembatan Kewek", "Yogyakarta Indonesia Train-at-Kewek-Railway-Bridge-01.jpg", "CEphoto, Uwe Aranas", "CC BY-SA 3.0"],
  ["Titik Nol Kilometer", "Gedung Bank BNI 1946 Yogyakarta.jpg", "Fandy Aprianto Rohman", "CC BY-SA 4.0"],
];

const WIDTH = 800; // lebar thumbnail standar Wikimedia

function imageUrl(file) {
  return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(file)}?width=${WIDTH}`;
}

function creditText(artist, license) {
  return `${artist} / Wikimedia Commons, ${license}`;
}

module.exports = { SPOT_IMAGES, imageUrl, creditText };

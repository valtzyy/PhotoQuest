import 'package:sqflite/sqflite.dart';

import '../models/quiz_question.dart';
import 'db_helper.dart';

/// Soal PhotoQuiz di sqflite (seed lokal, bisa dimainkan offline).
class QuizDao {
  QuizDao(this._helper);
  final DbHelper _helper;

  /// Isi tabel dengan soal bawaan jika masih kosong (dipanggil sebelum kuis dimulai).
  Future<void> ensureSeeded() async {
    final db = await _helper.database;
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM quiz_questions'),
        ) ??
        0;
    if (count > 0) return;
    final batch = db.batch();
    for (final q in quizSeed) {
      batch.insert('quiz_questions', q.toDb());
    }
    await batch.commit(noResult: true);
  }

  /// [count] soal dengan urutan acak (ORDER BY RANDOM()).
  Future<List<QuizQuestion>> randomQuestions({int count = 10}) async {
    await ensureSeeded();
    final db = await _helper.database;
    final rows = await db.query(
      'quiz_questions',
      orderBy: 'RANDOM()',
      limit: count,
    );
    return rows.map(QuizQuestion.fromDb).toList();
  }
}

/// 12 soal dasar fotografi.
const quizSeed = [
  QuizQuestion(
    question: 'Apa yang dimaksud dengan rule of thirds?',
    options: [
      'Membagi frame menjadi 3×3 dan menempatkan objek di garis/titik potongnya',
      'Memotret 3 kali untuk setiap objek',
      'Memakai 3 sumber cahaya',
      'Menggunakan 3 lensa berbeda',
    ],
    answerIndex: 0,
    explanation: 'Objek di titik potong garis 1/3 membuat komposisi lebih seimbang dan menarik.',
  ),
  QuizQuestion(
    question: 'Kapan golden hour terjadi?',
    options: [
      'Tepat tengah hari',
      'Sesaat setelah matahari terbit dan sebelum terbenam',
      'Tengah malam',
      'Saat hujan turun',
    ],
    answerIndex: 1,
    explanation: 'Matahari rendah menghasilkan cahaya hangat, lembut, dan bayangan panjang.',
  ),
  QuizQuestion(
    question: 'Menaikkan ISO akan membuat foto…',
    options: [
      'Lebih gelap dan lebih halus',
      'Lebih terang tetapi noise/bintik bertambah',
      'Lebih tajam tanpa efek samping',
      'Berwarna hitam putih',
    ],
    answerIndex: 1,
    explanation:
        'ISO tinggi menambah kepekaan sensor, tetapi juga menambah noise.',
  ),
  QuizQuestion(
    question: 'Aperture f/1.8 dibanding f/16 menghasilkan…',
    options: [
      'Bukaan lebih kecil, latar lebih tajam',
      'Bukaan lebih besar, latar lebih blur (bokeh)',
      'Tidak ada perbedaan',
      'Foto selalu lebih gelap',
    ],
    answerIndex: 1,
    explanation:
        'Angka f kecil = bukaan lebar = depth of field sempit (latar blur).',
  ),
  QuizQuestion(
    question: 'Shutter speed 1/1000 detik cocok untuk…',
    options: [
      'Membekukan objek yang bergerak cepat',
      'Membuat light trail kendaraan',
      'Memotret bintang',
      'Membuat air terjun terlihat halus',
    ],
    answerIndex: 0,
    explanation: 'Rana sangat cepat menghentikan gerakan; rana lambat membuat efek gerak.',
  ),
  QuizQuestion(
    question: 'Fungsi white balance adalah…',
    options: [
      'Mengatur ketajaman',
      'Menyesuaikan warna agar putih tampak putih sesuai sumber cahaya',
      'Mengatur zoom',
      'Menambah kontras',
    ],
    answerIndex: 1,
    explanation: 'White balance menetralkan warna dari cahaya lampu, matahari, atau mendung.',
  ),
  QuizQuestion(
    question: 'Leading lines dalam komposisi berfungsi untuk…',
    options: [
      'Menghiasi pinggir foto',
      'Mengarahkan mata penikmat foto menuju objek utama',
      'Mengurangi noise',
      'Membuat foto lebih terang',
    ],
    answerIndex: 1,
    explanation:
        'Jalan, pagar, atau garis pantai bisa menuntun pandangan ke subjek.',
  ),
  QuizQuestion(
    question: 'Blue hour adalah…',
    options: [
      'Saat langit biru cerah di siang hari',
      'Periode setelah matahari terbenam/sebelum terbit dengan langit kebiruan',
      'Saat memakai filter biru',
      'Jam kerja fotografer',
    ],
    answerIndex: 1,
    explanation:
        'Blue hour cocok untuk foto kota dengan lampu yang mulai menyala.',
  ),
  QuizQuestion(
    question: 'Tripod paling dibutuhkan ketika…',
    options: [
      'Memotret dengan shutter speed lambat',
      'Memotret di siang hari terik',
      'Memakai mode burst',
      'Memotret selfie dari dekat',
    ],
    answerIndex: 0,
    explanation: 'Rana lambat mudah blur karena guncangan tangan; tripod menjaga stabil.',
  ),
  QuizQuestion(
    question: 'Exposure triangle terdiri dari…',
    options: [
      'Zoom, fokus, flash',
      'ISO, aperture, shutter speed',
      'Kontras, saturasi, kecerahan',
      'Lensa, body, tripod',
    ],
    answerIndex: 1,
    explanation: 'Ketiganya saling memengaruhi terang-gelapnya foto.',
  ),
  QuizQuestion(
    question: 'Siluet didapat dengan cara…',
    options: [
      'Memotret objek dengan cahaya dari depan',
      'Memotret objek membelakangi sumber cahaya terang dan mengukur eksposur dari langit',
      'Menaikkan ISO setinggi mungkin',
      'Memakai flash penuh',
    ],
    answerIndex: 1,
    explanation:
        'Eksposur untuk langit membuat objek di depannya menjadi gelap pekat.',
  ),
  QuizQuestion(
    question: 'Mengapa horizon sebaiknya lurus?',
    options: [
      'Agar file lebih kecil',
      'Horizon miring terlihat tidak disengaja dan mengganggu keseimbangan foto',
      'Agar warna lebih tajam',
      'Supaya fokus otomatis bekerja',
    ],
    answerIndex: 1,
    explanation: 'Gunakan Level di PhotoQuest agar kemiringan ≤ 2°.',
  ),
];

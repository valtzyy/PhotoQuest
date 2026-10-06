import 'dart:convert';

/// Soal PhotoQuiz (disimpan di tabel lokal `quiz_questions`).
class QuizQuestion {
  const QuizQuestion({
    this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final int? id;
  final String question;
  final List<String> options;
  final int answerIndex; // indeks jawaban benar di [options]
  final String explanation;

  factory QuizQuestion.fromDb(Map<String, Object?> row) => QuizQuestion(
    id: row['id'] as int,
    question: row['question'] as String,
    options: List<String>.from(jsonDecode(row['options'] as String) as List),
    answerIndex: row['answer_index'] as int,
    explanation: (row['explanation'] as String?) ?? '',
  );

  Map<String, Object?> toDb() => {
    'question': question,
    'options': jsonEncode(options),
    'answer_index': answerIndex,
    'explanation': explanation,
  };
}

/// Satu ronde kuis: urutan soal, skor, dan jawaban yang dipilih.
class QuizSession {
  QuizSession(this.questions);

  final List<QuizQuestion> questions;
  int index = 0;
  int score = 0;
  int? selected; // jawaban yang dipilih untuk soal saat ini (null = belum)

  QuizQuestion get current => questions[index];
  bool get answered => selected != null;
  bool get isLast => index == questions.length - 1;
  bool finished = false;

  /// Pilih jawaban (hanya sekali per soal). true = benar.
  bool answer(int option) {
    if (answered) return selected == current.answerIndex;
    selected = option;
    final correct = option == current.answerIndex;
    if (correct) score++;
    return correct;
  }

  void next() {
    if (!answered) return;
    if (isLast) {
      finished = true;
    } else {
      index++;
      selected = null;
    }
  }
}

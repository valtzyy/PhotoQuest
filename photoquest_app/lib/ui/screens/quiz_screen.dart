import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/quiz_dao.dart';
import '../../data/models/quiz_question.dart';
import '../widgets/state_views.dart';

/// PhotoQuiz: 10 soal acak dari sqflite (offline), skor akhir, tombol ulangi.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizSession? _session;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  Future<void> _newRound() async {
    setState(() {
      _session = null;
      _error = null;
    });
    try {
      final questions = await context.read<QuizDao>().randomQuestions(
        count: 10,
      );
      if (mounted) setState(() => _session = QuizSession(questions));
    } catch (e) {
      if (mounted) setState(() => _error = 'Soal gagal dimuat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('PhotoQuiz')),
      body: _error != null
          ? Center(
              child: ErrorView(message: _error!, onRetry: _newRound),
            )
          : s == null
          ? const LoadingView()
          : s.questions.isEmpty
          ? const Center(child: EmptyView(message: 'Belum ada soal.'))
          : s.finished
          ? _finished(s)
          : _question(s),
    );
  }

  Widget _question(QuizSession s) {
    final theme = Theme.of(context);
    final q = s.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Soal ${s.index + 1} dari ${s.questions.length} · Skor ${s.score}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (s.index + 1) / s.questions.length),
        const SizedBox(height: 16),
        Text(q.question, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              text: q.options[i],
              state: !s.answered
                  ? _OptionState.normal
                  : i == q.answerIndex
                  ? _OptionState.correct
                  : i == s.selected
                  ? _OptionState.wrong
                  : _OptionState.disabled,
              onTap: s.answered ? null : () => setState(() => s.answer(i)),
            ),
          ),
        if (s.answered) ...[
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: Icon(
                s.selected == q.answerIndex ? Icons.check_circle : Icons.info,
              ),
              title: Text(
                s.selected == q.answerIndex ? 'Benar!' : 'Kurang tepat',
              ),
              subtitle: Text(q.explanation),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => setState(s.next),
            child: Text(s.isLast ? 'Lihat skor' : 'Lanjut'),
          ),
        ],
      ],
    );
  }

  Widget _finished(QuizSession s) {
    final theme = Theme.of(context);
    final total = s.questions.length;
    final ratio = s.score / total;
    final label = ratio >= 0.8
        ? 'Hebat! Kamu siap berburu foto 📸'
        : ratio >= 0.5
        ? 'Lumayan, terus belajar!'
        : 'Ayo coba lagi!';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Color(0xFFF9A825)),
            Text(
              'Skor ${s.score} / $total',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _newRound,
              icon: const Icon(Icons.replay),
              label: const Text('Ulangi'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OptionState { normal, correct, wrong, disabled }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.text, required this.state, this.onTap});

  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color? bg, IconData? icon) = switch (state) {
      _OptionState.correct => (const Color(0xFFC8E6C9), Icons.check),
      _OptionState.wrong => (const Color(0xFFFFCDD2), Icons.close),
      _ => (null, null),
    };
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(14),
        // Saat sudah dijawab tombol tidak aktif, tetapi warnanya tetap terlihat.
        disabledForegroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (icon != null) Icon(icon),
        ],
      ),
    );
  }
}

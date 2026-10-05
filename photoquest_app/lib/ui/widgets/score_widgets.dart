import 'package:flutter/material.dart';

import '../../data/models/score_result.dart';

/// Warna skor sesuai label: ≥80 hijau, 60–79 hijau muda, 40–59 kuning, <40 merah.
Color scoreColor(int score) {
  if (score >= 80) return const Color(0xFF2E7D32);
  if (score >= 60) return const Color(0xFF7CB342);
  if (score >= 40) return const Color(0xFFF9A825);
  return const Color(0xFFC62828);
}

/// Gauge melingkar skor 0–100 dengan label di tengah.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 14,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rincian skor per komponen (bar + catatan).
class ScoreBreakdownList extends StatelessWidget {
  const ScoreBreakdownList({super.key, required this.items});

  final List<ScoreComponent> items;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.label)),
                    Text(
                      '${_fmt(c.score)} / ${c.max}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: c.score / c.max,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 2),
                Text(c.note, style: small),
              ],
            ),
          ),
      ],
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Kartu rekomendasi terstruktur + penanda sumber (AI / template).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.isAi,
  });

  final Recommendation recommendation;
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = recommendation;

    Widget section(IconData icon, String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final l in lines) Text(lines.length > 1 ? '• $l' : l),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rekomendasi',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    isAi ? Icons.auto_awesome : Icons.description,
                    size: 16,
                  ),
                  label: Text(isAi ? 'AI (Gemini)' : 'Template'),
                ),
              ],
            ),
            if (!isAi)
              Text(
                'AI sedang tidak tersedia, memakai rekomendasi template.',
                style: theme.textTheme.bodySmall,
              ),
            section(Icons.grid_on, 'Komposisi', r.composition),
            section(Icons.schedule, 'Waktu', [r.timing]),
            section(Icons.place, 'Posisi', [r.position]),
            section(Icons.straighten, 'Stabilitas', [r.stability]),
            section(Icons.lightbulb_outline, 'Tips', r.tips),
          ],
        ),
      ),
    );
  }
}

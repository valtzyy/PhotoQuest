import 'weather_info.dart';

/// Satu komponen skor (timing / awan / hujan / kecocokan spot).
class ScoreComponent {
  const ScoreComponent({
    required this.key,
    required this.label,
    required this.score,
    required this.max,
    required this.note,
  });

  final String key;
  final String label;
  final double score;
  final int max;
  final String note;

  factory ScoreComponent.fromJson(Map<String, dynamic> json) => ScoreComponent(
    key: json['key'] as String,
    label: json['label'] as String,
    score: (json['score'] as num).toDouble(),
    max: (json['max'] as num).toInt(),
    note: json['note'] as String,
  );
}

/// Rekomendasi terstruktur (dari LLM atau template).
class Recommendation {
  const Recommendation({
    required this.composition,
    required this.timing,
    required this.position,
    required this.stability,
    required this.tips,
  });

  final List<String> composition;
  final String timing;
  final String position;
  final String stability;
  final List<String> tips;

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
    composition: List<String>.from(json['composition'] as List),
    timing: json['timing'] as String,
    position: json['position'] as String,
    stability: json['stability'] as String,
    tips: List<String>.from(json['tips'] as List),
  );

  Map<String, dynamic> toJson() => {
    'composition': composition,
    'timing': timing,
    'position': position,
    'stability': stability,
    'tips': tips,
  };
}

/// Respons POST /ai/score.
class ScoreResult {
  const ScoreResult({
    required this.score,
    required this.label,
    required this.breakdown,
    required this.cloudCover,
    required this.rainProb,
    required this.conditionSource,
    required this.weatherSource,
    required this.goldenMorning,
    required this.goldenEvening,
    required this.recommendation,
    required this.recommendationSource,
  });

  final int score;
  final String label;
  final List<ScoreComponent> breakdown;
  final double cloudCover;
  final double rainProb;

  /// manual | forecast | default
  final String conditionSource;

  /// live | cache | estimate
  final String weatherSource;
  final TimeRange goldenMorning;
  final TimeRange goldenEvening;
  final Recommendation recommendation;

  /// ai | template
  final String recommendationSource;

  bool get isAi => recommendationSource == 'ai';

  factory ScoreResult.fromJson(Map<String, dynamic> json) {
    final conditions = json['conditions'] as Map<String, dynamic>;
    final golden = json['golden_hour'] as Map<String, dynamic>;
    return ScoreResult(
      score: (json['score'] as num).toInt(),
      label: json['label'] as String,
      breakdown: (json['breakdown'] as List)
          .map((e) => ScoreComponent.fromJson(e as Map<String, dynamic>))
          .toList(),
      cloudCover: (conditions['cloud_cover'] as num).toDouble(),
      rainProb: (conditions['rain_prob'] as num).toDouble(),
      conditionSource: conditions['source'] as String,
      weatherSource: conditions['weather_source'] as String,
      goldenMorning: TimeRange.fromJson(
        golden['morning'] as Map<String, dynamic>,
      ),
      goldenEvening: TimeRange.fromJson(
        golden['evening'] as Map<String, dynamic>,
      ),
      recommendation: Recommendation.fromJson(
        json['recommendation'] as Map<String, dynamic>,
      ),
      recommendationSource: json['recommendation_source'] as String,
    );
  }
}

/// Sesi foto tersimpan (GET /sessions).
class PhotoSession {
  const PhotoSession({
    required this.id,
    required this.spotName,
    required this.photoType,
    required this.plannedAt,
    required this.score,
  });

  final int id;
  final String spotName;
  final String photoType;
  final DateTime plannedAt;
  final int score;

  factory PhotoSession.fromJson(Map<String, dynamic> json) => PhotoSession(
    id: json['id'] as int,
    spotName: json['spot_name'] as String,
    photoType: json['photo_type'] as String,
    plannedAt: DateTime.parse(json['planned_at'] as String),
    score: (json['score'] as num).toInt(),
  );
}

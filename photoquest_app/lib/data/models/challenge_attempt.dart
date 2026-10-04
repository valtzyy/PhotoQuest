/// Satu percobaan Steady Shot Challenge.
class ChallengeAttempt {
  const ChallengeAttempt({
    required this.id,
    required this.success,
    required this.holdSeconds,
    required this.avgTilt,
    required this.avgShake,
    required this.createdAt,
  });

  final int id;
  final bool success;
  final double holdSeconds;
  final double avgTilt;
  final double avgShake;
  final DateTime createdAt;

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) =>
      ChallengeAttempt(
        id: json['id'] as int,
        success: json['success'] as bool,
        holdSeconds: (json['hold_seconds'] as num).toDouble(),
        avgTilt: (json['avg_tilt'] as num).toDouble(),
        avgShake: (json['avg_shake'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'success': success,
    'hold_seconds': holdSeconds,
    'avg_tilt': avgTilt,
    'avg_shake': avgShake,
    'created_at': createdAt.toIso8601String(),
  };
}

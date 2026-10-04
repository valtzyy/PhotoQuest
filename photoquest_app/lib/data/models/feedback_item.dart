/// Satu entri Saran & Kesan mata kuliah PAM.
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.saran,
    required this.kesan,
    required this.createdAt,
  });

  final int id;
  final String saran;
  final String kesan;
  final DateTime createdAt;

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
    id: json['id'] as int,
    saran: json['saran'] as String,
    kesan: json['kesan'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'saran': saran,
    'kesan': kesan,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Satu entri Saran & Kesan mata kuliah PAM (dari pengguna mana pun).
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.saran,
    required this.kesan,
    required this.createdAt,
    this.authorName,
    this.mine = false,
  });

  final int id;
  final String saran;
  final String kesan;
  final DateTime createdAt;

  /// Nama penulis (email tidak pernah dikirim server).
  final String? authorName;

  /// true jika entri ini milik pengguna yang sedang login.
  final bool mine;

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
    id: json['id'] as int,
    saran: json['saran'] as String,
    kesan: json['kesan'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    authorName: json['name'] as String?,
    mine: json['mine'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'saran': saran,
    'kesan': kesan,
    'created_at': createdAt.toIso8601String(),
    'name': authorName,
    'mine': mine,
  };
}

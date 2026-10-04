/// Data user yang dikirim backend (tanpa password_hash).
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    photoUrl: json['photo_url'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'photo_url': photoUrl,
    'created_at': createdAt?.toIso8601String(),
  };
}

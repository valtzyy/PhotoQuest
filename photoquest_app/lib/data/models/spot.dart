import 'dart:convert';

/// Spot foto. Bisa dibuat dari JSON server maupun dari baris sqflite (cache).
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.bestTime,
    required this.photoTypes,
    this.tips,
    this.imageUrl,
    this.entryFeeIdr,
  });

  final int id;
  final String name;
  final String category; // landscape | architecture | street | nature | culture
  final String description;
  final double latitude;
  final double longitude;
  final String bestTime; // sunrise | sunset | any
  final List<String> photoTypes;
  final String? tips;
  final String? imageUrl;
  final int? entryFeeIdr;

  /// Dari respons API (photo_types berupa array JSON).
  factory Spot.fromJson(Map<String, dynamic> json) => Spot(
    id: json['id'] as int,
    name: json['name'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    bestTime: json['best_time'] as String,
    photoTypes: List<String>.from(json['photo_types'] as List),
    tips: json['tips'] as String?,
    imageUrl: json['image_url'] as String?,
    entryFeeIdr: json['entry_fee_idr'] as int?,
  );

  /// Dari baris tabel `spots_cache` (photo_types disimpan sebagai teks JSON).
  factory Spot.fromDb(Map<String, Object?> row) => Spot(
    id: row['id'] as int,
    name: row['name'] as String,
    category: row['category'] as String,
    description: row['description'] as String,
    latitude: row['latitude'] as double,
    longitude: row['longitude'] as double,
    bestTime: row['best_time'] as String,
    photoTypes: List<String>.from(
      jsonDecode(row['photo_types'] as String) as List,
    ),
    tips: row['tips'] as String?,
    imageUrl: row['image_url'] as String?,
    entryFeeIdr: row['entry_fee_idr'] as int?,
  );

  Map<String, Object?> toDb(DateTime cachedAt) => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'best_time': bestTime,
    'photo_types': jsonEncode(photoTypes),
    'tips': tips,
    'image_url': imageUrl,
    'entry_fee_idr': entryFeeIdr,
    'cached_at': cachedAt.toIso8601String(),
  };
}

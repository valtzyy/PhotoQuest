import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Satu blok blockchain PhotoQuest.
class ChainBlock {
  const ChainBlock({
    required this.blockIndex,
    required this.timestamp,
    required this.data,
    required this.prevHash,
    required this.hash,
    required this.nonce,
  });

  final int blockIndex;

  /// Disimpan sebagai teks ISO persis seperti dari server (dipakai untuk hash).
  final String timestamp;
  final Map<String, dynamic> data;
  final String prevHash;
  final String hash;
  final int nonce;

  bool get isGenesis => blockIndex == 0;

  factory ChainBlock.fromJson(Map<String, dynamic> json) => ChainBlock(
    blockIndex: json['block_index'] as int,
    timestamp: json['timestamp'] as String,
    data: json['data'] as Map<String, dynamic>,
    prevHash: json['prev_hash'] as String,
    hash: json['hash'] as String,
    nonce: json['nonce'] as int,
  );
}

/// Respons GET /chain.
class ChainInfo {
  const ChainInfo({
    required this.demoMode,
    required this.difficulty,
    required this.blocks,
  });

  final bool demoMode;
  final int difficulty;
  final List<ChainBlock> blocks;

  factory ChainInfo.fromJson(Map<String, dynamic> json) => ChainInfo(
    demoMode: json['demo_mode'] as bool,
    difficulty: json['difficulty'] as int,
    blocks: (json['blocks'] as List)
        .map((e) => ChainBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Hasil verifikasi chain (dari server maupun dihitung ulang di HP).
class ChainVerification {
  const ChainVerification({required this.valid, this.brokenAt, this.reason});

  final bool valid;
  final int? brokenAt;
  final String? reason;

  factory ChainVerification.fromJson(Map<String, dynamic> json) =>
      ChainVerification(
        valid: json['valid'] as bool,
        brokenAt: json['broken_at'] as int?,
        reason: json['reason'] as String?,
      );
}

/// Perhitungan hash di sisi aplikasi (sama persis dengan chainService.js di backend).
class ChainHasher {
  ChainHasher._();

  /// JSON kanonik: key objek diurutkan secara rekursif (sama dengan backend),
  /// karena urutan key JSON dari server tidak dijamin.
  static String canonicalJson(Object? value) {
    if (value is List) return '[${value.map(canonicalJson).join(',')}]';
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalJson(value[k])}').join(',')}}';
    }
    return jsonEncode(value);
  }

  /// hash = SHA-256(block_index + timestamp + JSON(data) + prev_hash + nonce)
  static String computeHash(ChainBlock b) {
    final input =
        '${b.blockIndex}${b.timestamp}${canonicalJson(b.data)}${b.prevHash}${b.nonce}';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Verifikasi seluruh chain dengan aturan yang sama seperti server.
  static ChainVerification verify(
    List<ChainBlock> blocks, {
    int difficulty = 2,
  }) {
    final prefix = '0' * difficulty;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final expectedPrev = i == 0 ? '0' : blocks[i - 1].hash;
      if (b.prevHash != expectedPrev) {
        return ChainVerification(
          valid: false,
          brokenAt: b.blockIndex,
          reason: 'prev_hash tidak cocok dengan hash blok sebelumnya',
        );
      }
      if (computeHash(b) != b.hash) {
        return ChainVerification(
          valid: false,
          brokenAt: b.blockIndex,
          reason: 'data blok diubah (hash tidak cocok)',
        );
      }
      if (!b.hash.startsWith(prefix)) {
        return ChainVerification(
          valid: false,
          brokenAt: b.blockIndex,
          reason: 'hash tidak memenuhi proof-of-work',
        );
      }
    }
    return const ChainVerification(valid: true);
  }

  /// Apakah hash satu blok cocok dengan isinya (untuk ikon ✓/✗ per blok).
  static bool blockIntact(ChainBlock b) => computeHash(b) == b.hash;
}

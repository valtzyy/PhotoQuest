/// Status pencatatan sebuah hasil challenge di blockchain Sepolia.
enum ChainStatus {
  pending, // transaksi dikirim / menunggu konfirmasi
  confirmed, // sudah masuk blok Sepolia
  failed; // gagal (bisa dikirim ulang)

  static ChainStatus parse(String? value) => switch (value) {
    'confirmed' => ChainStatus.confirmed,
    'failed' => ChainStatus.failed,
    _ => ChainStatus.pending,
  };
}

/// Satu catatan Steady Challenge di blockchain (satu transaksi Sepolia).
class ChainRecord {
  const ChainRecord({
    required this.attemptId,
    required this.userId,
    required this.holdSeconds,
    required this.avgTilt,
    required this.avgShake,
    required this.status,
    required this.createdAt,
    this.dataHash,
    this.txHash,
    this.error,
    this.chainIndex,
    this.blockNumber,
    this.confirmedAt,
    this.tampered = false,
    this.explorerUrl,
  });

  final int attemptId;
  final int userId;
  final double holdSeconds;
  final double avgTilt;
  final double avgShake;
  final ChainStatus status;
  final DateTime createdAt;
  final String? dataHash;
  final String? txHash;

  /// Alasan singkat bila [status] = failed.
  final String? error;

  /// Indeks catatan di smart contract (null selama belum confirmed).
  final int? chainIndex;
  final int? blockNumber;
  final DateTime? confirmedAt;

  /// true bila data di database sedang dimanipulasi (demo).
  final bool tampered;

  /// URL transaksi di Etherscan Sepolia (…/tx/HASH).
  final String? explorerUrl;

  factory ChainRecord.fromJson(Map<String, dynamic> json) => ChainRecord(
    attemptId: json['attempt_id'] as int,
    userId: json['user_id'] as int,
    holdSeconds: (json['hold_seconds'] as num).toDouble(),
    avgTilt: (json['avg_tilt'] as num).toDouble(),
    avgShake: (json['avg_shake'] as num).toDouble(),
    status: ChainStatus.parse(json['status'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String),
    dataHash: json['data_hash'] as String?,
    txHash: json['tx_hash'] as String?,
    error: json['error'] as String?,
    chainIndex: json['chain_index'] as int?,
    blockNumber: json['block_number'] as int?,
    confirmedAt: json['confirmed_at'] == null
        ? null
        : DateTime.parse(json['confirmed_at'] as String),
    tampered: json['tampered'] as bool? ?? false,
    explorerUrl: json['explorer_url'] as String?,
  );
}

/// Respons GET /chain.
class ChainInfo {
  const ChainInfo({
    required this.demoMode,
    required this.network,
    required this.configured,
    required this.records,
    this.contractAddress,
    this.contractUrl,
  });

  final bool demoMode;
  final String network;

  /// false bila backend belum diberi RPC/kunci/alamat kontrak.
  final bool configured;
  final String? contractAddress;
  final String? contractUrl;
  final List<ChainRecord> records;

  bool get hasPending => records.any((r) => r.status == ChainStatus.pending);
  bool get hasFailed => records.any((r) => r.status == ChainStatus.failed);

  factory ChainInfo.fromJson(Map<String, dynamic> json) => ChainInfo(
    demoMode: json['demo_mode'] as bool? ?? false,
    network: json['network'] as String? ?? 'sepolia',
    configured: json['configured'] as bool? ?? false,
    contractAddress: json['contract_address'] as String?,
    contractUrl: json['contract_url'] as String?,
    records: (json['records'] as List)
        .map((e) => ChainRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Satu catatan yang datanya di database tidak cocok dengan data on-chain.
class ChainMismatch {
  const ChainMismatch({
    required this.attemptId,
    required this.chainIndex,
    required this.reason,
  });

  final int attemptId;
  final int chainIndex;
  final String reason;

  factory ChainMismatch.fromJson(Map<String, dynamic> json) => ChainMismatch(
    attemptId: json['attempt_id'] as int,
    chainIndex: json['chain_index'] as int,
    reason: json['reason'] as String,
  );
}

/// Hasil GET /chain/verify: data database dibandingkan dengan catatan on-chain.
class ChainVerification {
  const ChainVerification({
    required this.valid,
    required this.checked,
    this.pending = 0,
    this.failed = 0,
    this.mismatches = const [],
  });

  final bool valid;

  /// Jumlah catatan on-chain yang dibandingkan.
  final int checked;
  final int pending;
  final int failed;
  final List<ChainMismatch> mismatches;

  factory ChainVerification.fromJson(Map<String, dynamic> json) =>
      ChainVerification(
        valid: json['valid'] as bool,
        checked: json['checked'] as int? ?? 0,
        pending: json['pending'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
        mismatches: ((json['mismatches'] as List?) ?? const [])
            .map((e) => ChainMismatch.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

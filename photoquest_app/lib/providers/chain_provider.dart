import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/chain_record.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/challenge_api.dart';

/// State Chain Explorer: catatan di blockchain Sepolia, verifikasi terhadap data on-chain,
/// retry, dan demo manipulasi. Selama ada transaksi "menunggu konfirmasi", daftar dimuat
/// ulang otomatis (server memperbarui status dari Sepolia setiap GET /chain).
class ChainProvider extends ChangeNotifier {
  ChainProvider(this._api, {this.pollInterval = const Duration(seconds: 12)});

  final ChallengeApi _api;
  final Duration pollInterval;

  ChainInfo? info;
  bool loading = false;
  bool busy = false; // verifikasi / retry / demo sedang berjalan
  String? error;

  /// Hasil GET /chain/verify (database vs on-chain).
  ChainVerification? verification;
  String? verifyError;

  Timer? _poll;
  bool _disposed = false;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      info = await _api.chain();
      error = null;
    } on ApiException catch (e) {
      // Pembaruan senyap yang gagal tidak menimpa data yang sudah tampil.
      if (!silent || info == null) error = e.message;
    } finally {
      loading = false;
      _schedulePoll();
      if (!_disposed) notifyListeners();
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = null;
    if (_disposed || !(info?.hasPending ?? false)) return;
    _poll = Timer(pollInterval, () => load(silent: true));
  }

  /// Bandingkan data database dengan catatan on-chain (dilakukan server).
  Future<void> verify() async {
    busy = true;
    verifyError = null;
    notifyListeners();
    try {
      await load(silent: true);
      verification = await _api.verify();
    } on ApiException catch (e) {
      verification = null;
      verifyError = e.message;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Kirim ulang catatan yang gagal. Mengembalikan pesan ringkas untuk snackbar.
  Future<String> retry() async {
    busy = true;
    notifyListeners();
    try {
      final queued = await _api.retry();
      await load(silent: true);
      return queued == 0
          ? 'Tidak ada catatan yang perlu dikirim ulang'
          : '$queued catatan dikirim ulang ke Sepolia';
    } on ApiException catch (e) {
      return e.message;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> tamper() => _demo(_api.tamperDemo);
  Future<void> repair() => _demo(_api.repairDemo);

  Future<void> _demo(Future<void> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      error = e.message;
      busy = false;
      notifyListeners();
      return;
    }
    await verify(); // tampilkan langsung dampaknya
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}

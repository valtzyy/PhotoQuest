import 'package:flutter/foundation.dart';

import '../data/models/chain_block.dart';
import '../data/remote/api_exception.dart';
import '../data/remote/challenge_api.dart';

/// State Chain Explorer: daftar blok, hasil verifikasi server & lokal, demo tamper.
class ChainProvider extends ChangeNotifier {
  ChainProvider(this._api);

  final ChallengeApi _api;

  ChainInfo? info;
  bool loading = false;
  bool busy = false; // verifikasi / demo sedang berjalan
  String? error;

  /// Hasil GET /chain/verify (server).
  ChainVerification? serverResult;

  /// Hasil hitung ulang SHA-256 di HP (package crypto).
  ChainVerification? localResult;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      info = await _api.chain();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Verifikasi oleh server + verifikasi ulang di HP, lalu bandingkan.
  Future<void> verify() async {
    busy = true;
    notifyListeners();
    try {
      await load(); // pastikan memakai data terbaru
      serverResult = await _api.verify();
      final i = info;
      if (i != null) {
        localResult = ChainHasher.verify(i.blocks, difficulty: i.difficulty);
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
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
}

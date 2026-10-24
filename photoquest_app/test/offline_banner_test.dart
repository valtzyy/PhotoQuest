// Uji: banner "Mode offline" di Home hilang lagi setelah koneksi kembali.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/models/user.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';

const _user = User(id: 4, name: 'Valzy', email: 'v@x.test');

/// Repository palsu: server bisa "mati" atau "hidup".
class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo(ApiClient client)
    : super(AuthApi(client), SecureStore(), DbHelper.instance);

  bool serverUp = false;
  int restoreCalls = 0;

  @override
  Future<RestoreResult> restoreSession() async {
    restoreCalls++;
    return serverUp
        ? const RestoreResult(RestoreStatus.online, user: _user)
        : const RestoreResult(RestoreStatus.offline, user: _user);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Balasan server apa pun menghapus status offline', () async {
    final client = ApiClient(SecureStore());
    final repo = _FakeAuthRepo(client);
    final auth = AuthProvider(repo, BiometricService(), client);
    await auth.restoreSession();
    expect(auth.isOffline, isTrue);

    client.onServerReachable!(); // mis. GET /weather berhasil setelah online
    expect(auth.isOffline, isFalse);
    auth.dispose();
  });

  test('Selama offline, koneksi dicek berkala sampai server terjangkau', () {
    fakeAsync((async) {
      final client = ApiClient(SecureStore());
      final repo = _FakeAuthRepo(client);
      final auth = AuthProvider(
        repo,
        BiometricService(),
        client,
        offlineRecheckInterval: const Duration(seconds: 15),
      );
      auth.restoreSession();
      async.flushMicrotasks();
      expect(auth.isOffline, isTrue);

      async.elapse(const Duration(seconds: 15)); // masih offline
      expect(repo.restoreCalls, 2);
      expect(auth.isOffline, isTrue);

      repo.serverUp = true; // internet kembali
      async.elapse(const Duration(seconds: 15));
      expect(repo.restoreCalls, 3);
      expect(auth.isOffline, isFalse);

      async.elapse(
        const Duration(minutes: 2),
      ); // berhenti mengecek setelah online
      expect(repo.restoreCalls, 3);
      auth.dispose();
    });
  });

  test(
    'Tarik-untuk-refresh: recheckConnection langsung menghapus banner',
    () async {
      final client = ApiClient(SecureStore());
      final repo = _FakeAuthRepo(client);
      final auth = AuthProvider(repo, BiometricService(), client);
      await auth.restoreSession();
      repo.serverUp = true;
      await auth.recheckConnection();
      expect(auth.isOffline, isFalse);
      auth.dispose();
    },
  );
}

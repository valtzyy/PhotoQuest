import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/json_cache.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/models/challenge_attempt.dart';
import 'package:photoquest_app/data/models/user.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/data/remote/user_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/profile_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';
import 'package:photoquest_app/ui/screens/profile_screen.dart';

final _client = ApiClient(SecureStore());

/// Repository palsu: ubah nama berhasil tanpa jaringan.
class _FakeProfileRepo extends ProfileRepository {
  _FakeProfileRepo()
    : super(
        UserApi(_client),
        ChallengeApi(_client),
        JsonCache(DbHelper.instance),
      );

  @override
  Future<User> updateName(String name) async =>
      User(id: 1, name: name.trim(), email: 'demo@photoquest.app');

  @override
  Future<CachedResult<List<ChallengeAttempt>>> challengeHistory() async =>
      const CachedResult(<ChallengeAttempt>[]);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  // Secure storage versi memori (tanpa platform channel).
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Ubah nama lewat dialog: tidak error & nama di layar berubah', (
    tester,
  ) async {
    final auth = AuthProvider(
      AuthRepository(AuthApi(_client), SecureStore(), DbHelper.instance),
      BiometricService(),
      _client,
    );
    await auth.updateUser(
      const User(id: 1, name: 'Demo User', email: 'demo@photoquest.app'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<ProfileRepository>.value(value: _FakeProfileRepo()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Nama Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle(); // termasuk animasi dialog menutup

    expect(tester.takeException(), isNull);
    expect(find.text('Nama Baru'), findsOneWidget);
    expect(auth.user!.name, 'Nama Baru');
  });

  testWidgets('Batal di dialog ubah nama: tidak error & nama tetap', (
    tester,
  ) async {
    final auth = AuthProvider(
      AuthRepository(AuthApi(_client), SecureStore(), DbHelper.instance),
      BiometricService(),
      _client,
    );
    await auth.updateUser(
      const User(id: 1, name: 'Demo User', email: 'demo@photoquest.app'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<ProfileRepository>.value(value: _FakeProfileRepo()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo User'), findsOneWidget);
  });
}

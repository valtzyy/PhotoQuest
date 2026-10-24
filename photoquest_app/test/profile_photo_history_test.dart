// Uji foto profil saat offline/online kembali dan pemuatan ulang riwayat challenge.

import 'package:flutter/foundation.dart';
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
import 'package:photoquest_app/data/remote/api_exception.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/data/remote/user_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/profile_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';
import 'package:photoquest_app/ui/screens/profile_screen.dart';
import 'package:photoquest_app/ui/widgets/user_avatar.dart';

final _client = ApiClient(SecureStore());
const _offline = ApiException('Tidak ada koneksi', isNetworkError: true);

// PNG 1x1 transparan.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Cache JSON di memori (tanpa sqflite).
class _MemCache extends JsonCache {
  _MemCache() : super(DbHelper.instance);
  final Map<String, ({Object? data, DateTime savedAt})> store = {};

  @override
  Future<void> save(String name, Object? json) async =>
      store[name] = (data: json, savedAt: DateTime(2026, 10, 24));

  @override
  Future<({Object? data, DateTime savedAt})?> read(String name) async =>
      store[name];
}

/// UserApi palsu: online/offline bisa diatur.
class _FakeUserApi extends UserApi {
  _FakeUserApi() : super(_client);
  bool online = true;

  @override
  Future<Uint8List> fetchPhoto(String photoUrl) async {
    if (!online) throw _offline;
    return _png;
  }
}

/// Repository palsu untuk widget: foto & riwayat dikendalikan tes.
class _FakeRepo extends ProfileRepository {
  _FakeRepo() : super(UserApi(_client), ChallengeApi(_client), _MemCache());

  bool photoOnline = false;
  int photoCalls = 0;
  int historyCalls = 0;
  List<ChallengeAttempt> history = const [];

  @override
  Future<CachedResult<Uint8List>> photo(String photoUrl) async {
    photoCalls++;
    if (!photoOnline) throw _offline;
    return CachedResult(_png);
  }

  @override
  Future<CachedResult<List<ChallengeAttempt>>> challengeHistory() async {
    historyCalls++;
    return CachedResult(history);
  }
}

ChallengeAttempt _attempt(int id, bool success) => ChallengeAttempt(
  id: id,
  success: success,
  holdSeconds: success ? 5 : 2.4,
  avgTilt: 1,
  avgShake: 0.1,
  createdAt: DateTime(2026, 10, 24, 16),
);

bool _hasPhoto(WidgetTester t) =>
    t.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage != null;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('ProfileRepository.photo (cache di HP)', () {
    test(
      'Online: foto diunduh dan disimpan; offline: foto tersimpan dipakai',
      () async {
        final api = _FakeUserApi();
        final cache = _MemCache();
        final repo = ProfileRepository(api, ChallengeApi(_client), cache);

        final online = await repo.photo('/users/1/photo?v=1');
        expect(online.fromCache, isFalse);
        expect(online.data, _png);

        api.online = false;
        final offline = await repo.photo('/users/1/photo?v=1');
        expect(offline.fromCache, isTrue);
        expect(offline.data, _png);
      },
    );

    test('Offline tanpa foto tersimpan: error jaringan diteruskan', () async {
      final api = _FakeUserApi()..online = false;
      final repo = ProfileRepository(api, ChallengeApi(_client), _MemCache());
      expect(
        () => repo.photo('/users/2/photo?v=1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  testWidgets(
    'UserAvatar: offline -> inisial, online lagi -> foto muncul sendiri',
    (t) async {
      final repo = _FakeRepo();
      await t.pumpWidget(
        Provider<ProfileRepository>.value(
          value: repo,
          child: const MaterialApp(
            home: UserAvatar(
              user: User(
                id: 9,
                name: 'Valzy',
                email: 'v@x.test',
                photoUrl: '/users/9/photo?v=offline-test',
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(_hasPhoto(t), isFalse);
      expect(find.text('V'), findsOneWidget);

      repo.photoOnline = true; // internet kembali
      await t.pump(
        UserAvatar.retryBaseDelay + const Duration(milliseconds: 50),
      );
      await t.pump();
      expect(repo.photoCalls, 2);
      expect(_hasPhoto(t), isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Profil: riwayat dimuat ulang saat tab dibuka lagi (termasuk yang gagal)',
    (t) async {
      final auth = AuthProvider(
        AuthRepository(AuthApi(_client), SecureStore(), DbHelper.instance),
        BiometricService(),
        _client,
      );
      await auth.updateUser(
        const User(id: 4, name: 'Valzy', email: 'v@x.test'),
      );
      final repo = _FakeRepo()..history = [_attempt(1, true)];
      final shown = ValueNotifier<int>(0);

      await t.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<ProfileRepository>.value(value: repo),
          ],
          child: MaterialApp(home: ProfileScreen(shown: shown)),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.historyCalls, 1);
      await t.scrollUntilVisible(find.text('Berhasil'), 200);
      expect(find.text('Gagal'), findsNothing);

      // Main challenge lalu kalah, kemudian kembali ke tab Profil.
      repo.history = [_attempt(2, false), _attempt(1, true)];
      shown.value++;
      await t.pumpAndSettle();
      expect(repo.historyCalls, 2);
      expect(find.text('Gagal'), findsOneWidget);
    },
  );
}

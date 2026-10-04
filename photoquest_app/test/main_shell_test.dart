import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/json_cache.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/models/challenge_attempt.dart';
import 'package:photoquest_app/data/models/feedback_item.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/data/remote/feedback_api.dart';
import 'package:photoquest_app/data/remote/user_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/data/repositories/cached_result.dart';
import 'package:photoquest_app/data/repositories/feedback_repository.dart';
import 'package:photoquest_app/data/repositories/profile_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';
import 'package:photoquest_app/ui/screens/main_shell.dart';

final _client = ApiClient(SecureStore());

/// Repository palsu: tidak memanggil jaringan saat tes.
class _FakeProfileRepo extends ProfileRepository {
  _FakeProfileRepo()
    : super(
        UserApi(_client),
        ChallengeApi(_client),
        JsonCache(DbHelper.instance),
      );

  @override
  Future<CachedResult<List<ChallengeAttempt>>> challengeHistory() async =>
      const CachedResult(<ChallengeAttempt>[]);
}

class _FakeFeedbackRepo extends FeedbackRepository {
  _FakeFeedbackRepo()
    : super(FeedbackApi(_client), JsonCache(DbHelper.instance));

  @override
  Future<CachedResult<List<FeedbackItem>>> getMine() async =>
      const CachedResult(<FeedbackItem>[]);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Widget buildShell() {
    final store = SecureStore();
    final auth = AuthProvider(
      AuthRepository(AuthApi(_client), store, DbHelper.instance),
      BiometricService(),
      _client,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<ProfileRepository>.value(value: _FakeProfileRepo()),
        Provider<FeedbackRepository>.value(value: _FakeFeedbackRepo()),
      ],
      child: const MaterialApp(home: MainShell()),
    );
  }

  testWidgets('Bottom nav punya 4 tab: Home, Profil, Saran & Kesan, Logout', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Profil', 'Saran & Kesan', 'Logout']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Tab Logout menampilkan dialog konfirmasi, Batal tetap di Home', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Yakin ingin keluar dari PhotoQuest?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Yakin ingin keluar dari PhotoQuest?'), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('Pindah ke tab Profil menampilkan riwayat kosong', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada percobaan'), findsOneWidget);
  });
}

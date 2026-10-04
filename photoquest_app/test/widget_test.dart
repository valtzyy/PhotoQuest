import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/auth_api.dart';
import 'package:photoquest_app/data/repositories/auth_repository.dart';
import 'package:photoquest_app/providers/auth_provider.dart';
import 'package:photoquest_app/services/biometric_service.dart';
import 'package:photoquest_app/ui/screens/login_screen.dart';

void main() {
  Widget buildLogin() {
    final store = SecureStore();
    final client = ApiClient(store);
    final auth = AuthProvider(AuthRepository(AuthApi(client), store), BiometricService(), client);
    return ChangeNotifierProvider.value(
      value: auth,
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('Login: field kosong menampilkan pesan validasi', (tester) async {
    await tester.pumpWidget(buildLogin());
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Password wajib diisi'), findsOneWidget);
  });

  testWidgets('Login: email salah format & password pendek ditolak', (tester) async {
    await tester.pumpWidget(buildLogin());
    await tester.enterText(find.byType(TextFormField).at(0), 'bukan-email');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Format email tidak valid'), findsOneWidget);
    expect(find.text('Password minimal 6 karakter'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'data/local/secure_store.dart';
import 'data/remote/api_client.dart';
import 'data/remote/auth_api.dart';
import 'data/repositories/auth_repository.dart';
import 'providers/auth_provider.dart';
import 'services/biometric_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/register_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Susun dependensi sekali di sini (manual dependency injection).
  final store = SecureStore();
  final apiClient = ApiClient(store);
  final authProvider = AuthProvider(
    AuthRepository(AuthApi(apiClient), store),
    BiometricService(),
    apiClient,
  );

  // Saat token ditolak server (401): kembali ke Login dari layar mana pun.
  authProvider.onSessionExpired = (message) {
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    scaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBar(content: Text(message)));
  };

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const PhotoQuestApp(),
    ),
  );
}

class PhotoQuestApp extends StatelessWidget {
  const PhotoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
      },
    );
  }
}

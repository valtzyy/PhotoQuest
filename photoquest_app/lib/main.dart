import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'data/local/db_helper.dart';
import 'data/local/json_cache.dart';
import 'data/local/secure_store.dart';
import 'data/remote/api_client.dart';
import 'data/remote/auth_api.dart';
import 'data/remote/challenge_api.dart';
import 'data/local/spot_dao.dart';
import 'data/remote/feedback_api.dart';
import 'data/remote/spot_api.dart';
import 'data/remote/user_api.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/spot_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/spot_provider.dart';
import 'services/biometric_service.dart';
import 'services/location_service.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/register_screen.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data format tanggal bahasa Indonesia untuk intl (DateFormat 'id_ID').
  await initializeDateFormatting('id_ID');

  // Susun dependensi sekali di sini (manual dependency injection).
  final store = SecureStore();
  final db = DbHelper.instance;
  final jsonCache = JsonCache(db);
  final apiClient = ApiClient(store);

  final authProvider = AuthProvider(
    AuthRepository(AuthApi(apiClient), store, db),
    BiometricService(),
    apiClient,
  );

  final spotRepository = SpotRepository(SpotApi(apiClient), SpotDao(db));
  final spotProvider = SpotProvider(spotRepository);
  final locationProvider = LocationProvider(LocationService(), db);

  // Setelah logout, favorit user sebelumnya tidak boleh terlihat user berikutnya.
  authProvider.addListener(() {
    if (authProvider.status == AuthStatus.unauthenticated) {
      spotProvider.clearUserState();
    }
  });

  // Saat token ditolak server (401): kembali ke Login dari layar mana pun.
  authProvider.onSessionExpired = (message) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  };

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<DbHelper>.value(value: db),
        Provider<ProfileRepository>.value(
          value: ProfileRepository(
            UserApi(apiClient),
            ChallengeApi(apiClient),
            jsonCache,
          ),
        ),
        Provider<FeedbackRepository>.value(
          value: FeedbackRepository(FeedbackApi(apiClient), jsonCache),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        Provider<SpotRepository>.value(value: spotRepository),
        ChangeNotifierProvider<SpotProvider>.value(value: spotProvider),
        ChangeNotifierProvider<LocationProvider>.value(value: locationProvider),
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
        AppRoutes.home: (_) => const MainShell(),
      },
    );
  }
}

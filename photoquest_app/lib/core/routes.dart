import 'package:flutter/material.dart';

/// Nama route aplikasi.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
}

/// Key global agar navigasi & snackbar bisa dilakukan dari luar widget
/// (mis. saat interceptor mendeteksi 401 dan harus kembali ke Login).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

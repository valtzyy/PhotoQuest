import 'package:flutter/material.dart';

import '../widgets/glass/glass_panel.dart';
import '../widgets/glass/pq_background.dart';
import '../widgets/logout_dialog.dart';
import 'feedback_screen.dart';
import 'home_tab.dart';
import 'profile_screen.dart';

/// Kerangka utama dengan Bottom Navigation: Home | Profil | Saran & Kesan | Logout.
///
/// Tab Logout tidak membuka halaman, hanya menampilkan dialog konfirmasi.
/// IndexedStack menjaga state setiap tab (posisi scroll, isi form) saat berpindah.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _profileIndex = 1;
  static const _logoutIndex = 3;
  int _index = 0;

  /// Memberi tahu tab Profil bahwa ia dibuka lagi (riwayat challenge dimuat ulang).
  final _profileShown = ValueNotifier<int>(0);

  @override
  void dispose() {
    _profileShown.dispose();
    super.dispose();
  }

  void _onSelect(int index) {
    if (index == _logoutIndex) {
      confirmLogout(context); // index tidak berubah: tetap di tab sebelumnya
      return;
    }
    if (index == _profileIndex && _index != _profileIndex) {
      _profileShown.value++;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index,
          children: [
            const HomeTab(),
            ProfileScreen(shown: _profileShown),
            const FeedbackScreen(),
          ],
        ),
        // Nav kaca melayang (satu-satunya panel dengan blur).
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            blur: true,
            radius: 28,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onSelect,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.rate_review_outlined),
                  selectedIcon: Icon(Icons.rate_review),
                  label: 'Saran & Kesan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.logout),
                  label: 'Logout',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

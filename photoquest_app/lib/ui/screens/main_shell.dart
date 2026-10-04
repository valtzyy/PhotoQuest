import 'package:flutter/material.dart';

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
  static const _logoutIndex = 3;
  int _index = 0;

  void _onSelect(int index) {
    if (index == _logoutIndex) {
      confirmLogout(context); // index tidak berubah: tetap di tab sebelumnya
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeTab(), ProfileScreen(), FeedbackScreen()],
      ),
      bottomNavigationBar: NavigationBar(
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
          NavigationDestination(icon: Icon(Icons.logout), label: 'Logout'),
        ],
      ),
    );
  }
}

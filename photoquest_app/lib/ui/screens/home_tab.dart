import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';
import '../widgets/weather_card.dart';
import 'explore_screen.dart';
import 'level_stabilizer_screen.dart';
import 'nearby_map_screen.dart';

/// Satu item menu di grid Home.
class _MenuItem {
  const _MenuItem(this.label, this.icon, this.phase, [this.builder]);
  final String label;
  final IconData icon;
  final int phase; // fase pengerjaan (sementara, untuk pesan "segera hadir")
  final WidgetBuilder? builder; // layar tujuan; null = belum dibuat
}

final _menu = [
  _MenuItem('Explore', Icons.explore, 4, (_) => const ExploreScreen()),
  _MenuItem('Peta Terdekat', Icons.map, 5, (_) => const NearbyMapScreen()),
  _MenuItem('Plan (AI)', Icons.insights, 8),
  _MenuItem('Assistant', Icons.chat_bubble, 8),
  _MenuItem(
    'Level & Stabilizer',
    Icons.straighten,
    7,
    (_) => const LevelStabilizerScreen(),
  ),
  _MenuItem('Steady Challenge', Icons.sports_esports, 10),
  _MenuItem('PhotoQuiz', Icons.quiz, 10),
  _MenuItem('Konverter', Icons.currency_exchange, 9),
  _MenuItem('Chain Explorer', Icons.link, 10),
];

/// Tab Home: sapaan + kartu cuaca singkat + grid menu fitur.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, _MenuItem item) {
    if (item.builder != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: item.builder!));
      return;
    }
    // Sementara: menu lain dihubungkan ke layarnya pada fase masing-masing.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${item.label} dibuat di Fase ${item.phase}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          if (auth.isOffline) const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header sapaan
                Row(
                  children: [
                    UserAvatar(user: auth.user, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${auth.user?.name ?? ''}',
                            style: theme.textTheme.titleLarge,
                          ),
                          const Text('Siap berburu cahaya hari ini?'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Kartu cuaca singkat + golden hour hari ini (Open-Meteo via backend)
                const WeatherCard(),
                const SizedBox(height: 16),
                Text('Menu', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final item in _menu)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(context, item),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

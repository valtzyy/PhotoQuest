import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pq_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/weather_provider.dart';
import '../widgets/glass/glass_icon_tile.dart';
import '../widgets/glass/glass_pressable.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';
import '../widgets/weather_card.dart';
import 'assistant_screen.dart';
import 'chain_explorer_screen.dart';
import 'converter_screen.dart';
import 'explore_screen.dart';
import 'level_stabilizer_screen.dart';
import 'nearby_map_screen.dart';
import 'plan_screen.dart';
import 'quiz_screen.dart';
import 'steady_challenge_screen.dart';

/// Satu item menu di grid Home: label, ikon, warna tile, dan layar tujuan.
class _MenuItem {
  const _MenuItem(this.label, this.icon, this.colors, this.builder);
  final String label;
  final IconData icon;
  final List<Color> colors;
  final WidgetBuilder builder;
}

final _menu = [
  _MenuItem(
    'Explore',
    Icons.explore,
    PqPalette.tileRed,
    (_) => const ExploreScreen(),
  ),
  _MenuItem(
    'Peta Terdekat',
    Icons.map,
    PqPalette.tileBlue,
    (_) => const NearbyMapScreen(),
  ),
  _MenuItem(
    'Plan (AI)',
    Icons.insights,
    PqPalette.tilePurple,
    (_) => const PlanScreen(),
  ),
  _MenuItem(
    'Assistant',
    Icons.chat_bubble,
    PqPalette.tileGreen,
    (_) => const AssistantScreen(),
  ),
  _MenuItem(
    'Level & Stabilizer',
    Icons.straighten,
    PqPalette.tileYellow,
    (_) => const LevelStabilizerScreen(),
  ),
  _MenuItem(
    'Steady Challenge',
    Icons.sports_esports,
    PqPalette.tileOrange,
    (_) => const SteadyChallengeScreen(),
  ),
  _MenuItem(
    'PhotoQuiz',
    Icons.quiz,
    PqPalette.tilePurple,
    (_) => const QuizScreen(),
  ),
  _MenuItem(
    'Konverter',
    Icons.currency_exchange,
    PqPalette.tileGreen,
    (_) => const ConverterScreen(),
  ),
  _MenuItem(
    'Chain Explorer',
    Icons.link,
    PqPalette.tileBlue,
    (_) => const ChainExplorerScreen(),
  ),
];

/// Tab Home: sapaan + kartu cuaca singkat + grid menu fitur.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, _MenuItem item) =>
      Navigator.of(context).push(MaterialPageRoute(builder: item.builder));

  /// Tarik-untuk-refresh: muat ulang cuaca di titik yang sama dengan kartu cuaca.
  Future<void> _refresh(BuildContext context) {
    final point =
        context.read<LocationProvider>().position ?? LocationProvider.demoPoint;
    return Future.wait([
      context.read<AuthProvider>().recheckConnection(),
      context.read<WeatherProvider>().load(
        point.latitude,
        point.longitude,
        force: true,
      ),
    ]);
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
            child: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                // Selalu bisa ditarik, walau isi Home muat dalam satu layar.
                physics: const AlwaysScrollableScrollPhysics(),
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
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final item in _menu)
                        GlassPressable(
                          onTap: () => _open(context, item),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GlassIconTile(
                                icon: item.icon,
                                colors: item.colors,
                                size: 40,
                              ),
                              const SizedBox(height: 6),
                              // Flexible: label panjang/skala font besar
                              // dipotong, bukan overflow.
                              Flexible(
                                child: Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: PqColors.of(context).text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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

/// Satu item menu di grid Home: label, ikon, dan layar tujuan.
class _MenuItem {
  const _MenuItem(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final _menu = [
  _MenuItem('Explore', Icons.explore, (_) => const ExploreScreen()),
  _MenuItem('Peta Terdekat', Icons.map, (_) => const NearbyMapScreen()),
  _MenuItem('Plan (AI)', Icons.insights, (_) => const PlanScreen()),
  _MenuItem('Assistant', Icons.chat_bubble, (_) => const AssistantScreen()),
  _MenuItem(
    'Level & Stabilizer',
    Icons.straighten,
    (_) => const LevelStabilizerScreen(),
  ),
  _MenuItem(
    'Steady Challenge',
    Icons.sports_esports,
    (_) => const SteadyChallengeScreen(),
  ),
  _MenuItem('PhotoQuiz', Icons.quiz, (_) => const QuizScreen()),
  _MenuItem(
    'Konverter',
    Icons.currency_exchange,
    (_) => const ConverterScreen(),
  ),
  _MenuItem('Chain Explorer', Icons.link, (_) => const ChainExplorerScreen()),
];

/// Tab Home: sapaan + kartu cuaca singkat + grid menu fitur.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, _MenuItem item) =>
      Navigator.of(context).push(MaterialPageRoute(builder: item.builder));
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

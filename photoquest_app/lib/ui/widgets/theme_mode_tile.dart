import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_mode_provider.dart';

/// Baris pengaturan "Tema tampilan" di Profil: Sistem / Terang / Gelap.
class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    // Opsional: layar yang dipasang tanpa provider ini (mis. di test) tetap tampil.
    final provider = context.watch<ThemeModeProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: theme.listTileTheme.iconColor,
              ),
              const SizedBox(width: 16),
              Text('Tema tampilan', style: theme.textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('Sistem'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Terang'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Gelap'),
                ),
              ],
              selected: {provider.mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => provider.setMode(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

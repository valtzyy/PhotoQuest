import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../providers/sensor_provider.dart';
import '../widgets/sensor_widgets.dart';

/// Level & Stabilizer: accelerometer (kemiringan) + gyroscope (getaran).
class LevelStabilizerScreen extends StatelessWidget {
  const LevelStabilizerScreen({super.key, this.createSensors});

  /// Untuk tes: sumber sensor palsu. Default memakai sensor HP.
  final SensorProvider Function()? createSensors;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SensorProvider>(
      // create + ChangeNotifierProvider -> dispose() otomatis saat layar ditutup,
      // sehingga subscription stream sensor ikut dibatalkan.
      create: (_) => (createSensors?.call() ?? SensorProvider())..start(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Level & Stabilizer')),
        body: Consumer<SensorProvider>(
          builder: (context, s, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LevelCard(sensors: s),
              const SizedBox(height: 16),
              _StabilityCard(sensors: s),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.tips_and_updates_outlined),
                  title: Text('Tips'),
                  subtitle: Text(
                    'Pegang HP dengan dua tangan, rapatkan siku ke badan, '
                    'dan tahan napas sejenak saat menekan tombol rana.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.sensors});
  final SensorProvider sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sensors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten),
                const SizedBox(width: 8),
                Text(
                  'Level (accelerometer)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.accelError != null)
              _SensorUnavailable(message: s.accelError!)
            else if (!s.hasAccelData)
              const Center(child: CircularProgressIndicator())
            else ...[
              BubbleLevel(roll: s.roll),
              const SizedBox(height: 16),
              Text(
                '${Formatters.decimal(s.roll, digits: 1)}°',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium,
              ),
              Text(
                levelLabel(s.roll),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: levelColor(s.roll),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pitch ${Formatters.decimal(s.pitch, digits: 1)}° '
                '(≈0° datar di meja, ≈90° HP tegak)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StabilityCard extends StatelessWidget {
  const _StabilityCard({required this.sensors});
  final SensorProvider sensors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = sensors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.vibration),
                const SizedBox(width: 8),
                Text(
                  'Stabilitas (gyroscope)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.gyroError != null)
              _SensorUnavailable(message: s.gyroError!)
            else if (!s.hasGyroData)
              const Center(child: CircularProgressIndicator())
            else ...[
              StabilityBar(magnitude: s.shake),
              const SizedBox(height: 12),
              Text(
                s.stability.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: stabilityColor(s.stability),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${Formatters.decimal(s.shake)} rad/s (rata-rata 10 sampel)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pesan jika sensor tidak ada / gagal dibaca (aplikasi tidak crash).
class _SensorUnavailable extends StatelessWidget {
  const _SensorUnavailable({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      Icons.sensors_off,
      color: Theme.of(context).colorScheme.error,
    ),
    title: Text(message),
    subtitle: const Text('Fitur ini membutuhkan sensor tersebut.'),
  );
}

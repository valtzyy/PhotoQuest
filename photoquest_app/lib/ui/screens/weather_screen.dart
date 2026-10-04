import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/weather_info.dart';
import '../../providers/weather_provider.dart';
import '../widgets/state_views.dart';
import '../widgets/weather_widgets.dart';

/// Detail cuaca & golden hour: cuaca saat ini, prakiraan per jam (awan & hujan),
/// dan jadwal sunrise/sunset + golden hour 7 hari.
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final result = weather.resultFor(latitude, longitude);
    final loading = weather.isLoading(latitude, longitude);
    final error = weather.errorFor(latitude, longitude);
    final theme = Theme.of(context);
    final now = DateTime.now();

    Future<void> refresh() => weather.load(latitude, longitude, force: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuaca & Golden Hour')),
      body: Builder(
        builder: (_) {
          if (result == null && loading) return const LoadingView();
          if (result == null) {
            return Center(
              child: ErrorView(
                message: error ?? 'Cuaca belum dimuat',
                onRetry: refresh,
              ),
            );
          }
          final info = result.data;
          final current = info.current;
          final todayDate = info.dayFor(now)?.date; // tanggal hari ini (WIB)
          // Prakiraan 24 jam ke depan
          final next24 = info.hourly
              .where(
                (h) =>
                    h.time.isAfter(now.subtract(const Duration(hours: 1))) &&
                    h.time.isBefore(now.add(const Duration(hours: 24))),
              )
              .toList();

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (result.fromCache) OfflineBanner(cachedAt: result.cachedAt),
                if (info.isEstimate)
                  Card(
                    color: theme.colorScheme.tertiaryContainer,
                    child: const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Data cuaca tidak tersedia'),
                      subtitle: Text(
                        'Jadwal memakai estimasi: sunrise 05.30 & sunset 17.45 WIB.',
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.thermostat, size: 36),
                    title: Text(
                      current == null
                          ? 'Cuaca saat ini tidak tersedia'
                          : '${current.temperature.toStringAsFixed(1)}°C · ${current.description}',
                    ),
                    subtitle: Text(
                      current == null
                          ? 'Diperbarui ${Formatters.dateTime(info.fetchedAt)}'
                          : 'Tutupan awan ${current.cloudCover}% · '
                                'diperbarui ${Formatters.dateTime(info.fetchedAt)}',
                    ),
                    trailing: WeatherSourceChip(result: result),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Golden hour 7 hari (WIB)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                for (final d in info.days)
                  _dayTile(context, d, now, isToday: d.date == todayDate),
                if (next24.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('24 jam ke depan', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: next24.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _hourTile(context, next24[i]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dayTile(
    BuildContext context,
    DayLight d,
    DateTime now, {
    required bool isToday,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.dayLabel(d.date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Terbit ${Formatters.timeWib(d.sunrise)} · '
              'Terbenam ${Formatters.timeWib(d.sunset)}',
            ),
            Text(
              'Golden pagi ${Formatters.rangeWib(d.goldenMorning.start, d.goldenMorning.end)}'
              '${isToday ? ' (${goldenStatus(d.goldenMorning, now)})' : ''}',
            ),
            Text(
              'Golden sore ${Formatters.rangeWib(d.goldenEvening.start, d.goldenEvening.end)}'
              '${isToday ? ' (${goldenStatus(d.goldenEvening, now)})' : ''}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourTile(BuildContext context, HourlyPoint h) {
    return Container(
      width: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            Formatters.timeWib(h.time),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('☁ ${h.cloudCover}%'),
          Text('☂ ${h.precipitationProbability}%'),
        ],
      ),
    );
  }
}

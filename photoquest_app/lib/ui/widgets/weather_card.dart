import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../providers/location_provider.dart';
import '../../providers/weather_provider.dart';
import '../screens/weather_screen.dart';
import 'weather_widgets.dart';

/// Kartu cuaca singkat di Home: cuaca saat ini + golden hour hari ini.
/// Lokasi: posisi GPS terakhir, atau lokasi demo (Tugu Jogja) bila belum ada.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  String? _requestedKey;

  @override
  void initState() {
    super.initState();
    // Muat preferensi lokasi (posisi terakhir / mode demo) dari sqflite.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LocationProvider>().init(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final weather = context.watch<WeatherProvider>();
    final point = loc.position ?? LocationProvider.demoPoint;
    final lat = point.latitude;
    final lng = point.longitude;

    // Muat cuaca saat lokasi berubah (dibulatkan ~1 km).
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (key != _requestedKey) {
      _requestedKey = key;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<WeatherProvider>().load(lat, lng),
      );
    }

    final result = weather.resultFor(lat, lng);
    final error = weather.errorFor(lat, lng);
    final theme = Theme.of(context);
    final now = DateTime.now();

    Widget content;
    if (result == null && error == null) {
      content = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (result == null) {
      content = ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Cuaca gagal dimuat'),
        subtitle: Text(error!),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => weather.load(lat, lng, force: true),
        ),
      );
    } else {
      final info = result.data;
      final today = info.dayFor(now);
      final current = info.current;
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_twilight, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current == null
                            ? 'Cuaca tidak tersedia'
                            : '${current.temperature.round()}°C · ${current.description}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${current == null ? '' : 'Awan ${current.cloudCover}% · '}'
                        '${loc.isDemo || loc.position == null ? 'Lokasi demo' : 'Lokasi Anda'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                WeatherSourceChip(result: result),
              ],
            ),
            if (today != null) ...[
              const Divider(),
              _goldenRow(
                context,
                'Golden hour pagi',
                Formatters.rangeWib(
                  today.goldenMorning.start,
                  today.goldenMorning.end,
                ),
                goldenStatus(today.goldenMorning, now),
              ),
              _goldenRow(
                context,
                'Golden hour sore',
                Formatters.rangeWib(
                  today.goldenEvening.start,
                  today.goldenEvening.end,
                ),
                goldenStatus(today.goldenEvening, now),
              ),
            ],
          ],
        ),
      );
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: result == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WeatherScreen(latitude: lat, longitude: lng),
                ),
              ),
        child: content,
      ),
    );
  }

  Widget _goldenRow(
    BuildContext context,
    String label,
    String range,
    String status,
  ) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$range WIB',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(status, style: small, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

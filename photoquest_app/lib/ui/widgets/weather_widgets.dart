import 'package:flutter/material.dart';

import '../../data/models/weather_info.dart';
import '../../data/repositories/cached_result.dart';

/// Status golden hour relatif terhadap waktu sekarang.
/// Contoh: "Sedang berlangsung", "Mulai 2 j 15 mnt lagi", "Sudah lewat".
String goldenStatus(TimeRange range, DateTime now) {
  if (range.contains(now)) return 'Sedang berlangsung';
  if (now.isAfter(range.end)) return 'Sudah lewat';
  final diff = range.start.difference(now);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return h > 0 ? 'Mulai $h j $m mnt lagi' : 'Mulai $m mnt lagi';
}

/// Label sumber data cuaca agar jelas data asli, cache, atau estimasi.
class WeatherSourceChip extends StatelessWidget {
  const WeatherSourceChip({super.key, required this.result});

  final CachedResult<WeatherInfo> result;

  @override
  Widget build(BuildContext context) {
    final info = result.data;
    final (String label, IconData icon) = info.isEstimate
        ? ('Estimasi', Icons.help_outline)
        : result.fromCache
        ? ('Offline (cache)', Icons.cloud_off)
        : info.source == 'cache'
        ? ('Cache server', Icons.history)
        : ('Live', Icons.wifi);
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

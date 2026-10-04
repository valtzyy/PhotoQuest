import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/spot.dart';
import 'spot_placeholder.dart';

/// Kartu spot di daftar Explore: gambar/placeholder, nama, kategori, jarak (jika ada).
class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.spot,
    required this.isFavorite,
    required this.onTap,
    this.distanceKm,
  });

  final Spot spot;
  final bool isFavorite;
  final VoidCallback onTap;

  /// Jarak dari posisi user. Diisi mulai Fase 5 (LBS); null = lokasi belum ada.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: SpotPlaceholder(category: spot.category, iconSize: 36),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Labels.category(spot.category)} · ${Labels.bestTime(spot.bestTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.near_me, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            Formatters.distance(distanceKm!),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

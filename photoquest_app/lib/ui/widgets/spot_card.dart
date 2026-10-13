import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/pq_colors.dart';
import '../../data/models/spot.dart';
import 'glass/holo_card_frame.dart';
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

  /// Jarak dari posisi user (LBS); null = lokasi belum diketahui.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Kartu koleksi horizontal: gambar di kiri, info di kanan (ringkas agar
    // beberapa spot terlihat sekaligus di daftar).
    return HoloCardFrame(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 84,
              height: 84,
              child: SpotPlaceholder(category: spot.category, iconSize: 36),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
          Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? PqPalette.danger : theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/spot.dart';
import '../../providers/spot_provider.dart';
import '../widgets/spot_placeholder.dart';

/// Detail spot: deskripsi, waktu terbaik, jenis foto, tips, favorit,
/// tombol "Rencanakan Foto di Sini" dan "Tanya Assistant".
class SpotDetailScreen extends StatefulWidget {
  const SpotDetailScreen({super.key, required this.spot});

  final Spot spot;

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  late Spot _spot = widget.spot;
  bool _togglingFav = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Tampilkan data dari daftar dulu, lalu perbarui diam-diam dari GET /spots/:id.
  Future<void> _refresh() async {
    try {
      final fresh = await context.read<SpotProvider>().fetchSpot(
        widget.spot.id,
      );
      if (mounted) setState(() => _spot = fresh);
    } catch (_) {
      // Tetap memakai data yang sudah ada.
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleFavorite() async {
    setState(() => _togglingFav = true);
    final provider = context.read<SpotProvider>();
    final wasFavorite = provider.isFavorite(_spot.id);
    final error = await provider.toggleFavorite(_spot.id);
    if (!mounted) return;
    setState(() => _togglingFav = false);
    _snack(
      error ??
          (wasFavorite ? 'Dihapus dari favorit' : 'Ditambahkan ke favorit'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFav = context.watch<SpotProvider>().isFavorite(_spot.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _spot.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: SpotPlaceholder(
                category: _spot.category,
                iconSize: 72,
              ),
            ),
            actions: [
              IconButton(
                tooltip: isFav ? 'Hapus dari favorit' : 'Tambah ke favorit',
                onPressed: _togglingFav ? null : _toggleFavorite,
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        Labels.categoryIcon(_spot.category),
                        size: 18,
                      ),
                      label: Text(Labels.category(_spot.category)),
                    ),
                    Chip(
                      avatar: const Icon(Icons.wb_twilight, size: 18),
                      label: Text(Labels.bestTime(_spot.bestTime)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_spot.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                Text('Cocok untuk foto', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in _spot.photoTypes)
                      Chip(label: Text(Labels.photoType(t))),
                  ],
                ),
                if (_spot.tips != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: const Text('Tips'),
                      subtitle: Text(_spot.tips!),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(
                    _spot.entryFeeIdr == null
                        ? 'Gratis / belum diketahui'
                        : '${Formatters.rupiah(_spot.entryFeeIdr!)} (perkiraan)',
                  ),
                  subtitle: const Text('Tiket masuk'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    '${_spot.latitude.toStringAsFixed(4)}, ${_spot.longitude.toStringAsFixed(4)}',
                  ),
                  subtitle: const Text('Koordinat'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  // Dihubungkan ke layar Plan (AI) di Fase 8.
                  onPressed: () => _snack('Plan (AI) dibuat di Fase 8'),
                  icon: const Icon(Icons.insights),
                  label: const Text('Rencanakan Foto di Sini'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  // Dihubungkan ke Photography Assistant di Fase 8.
                  onPressed: () => _snack('Assistant dibuat di Fase 8'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Tanya Assistant'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

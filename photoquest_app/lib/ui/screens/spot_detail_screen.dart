import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/pq_colors.dart';
import '../../data/models/spot.dart';
import '../../providers/spot_provider.dart';
import '../widgets/glass/pq_background.dart';
import '../widgets/spot_image.dart';
import 'assistant_screen.dart';
import 'plan_screen.dart';

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

  static const double _headerHeight = 220;

  static final ButtonStyle _overlayButtonStyle = IconButton.styleFrom(
    backgroundColor: Colors.black38,
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white54,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFav = context.watch<SpotProvider>().isFavorite(_spot.id);

    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: _headerHeight,
              // Appbar tema transparan; saat menciut perlu latar agar judul
              // tidak tertimpa konten yang digulir di bawahnya.
              backgroundColor: PqColors.of(context).bgBase,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  // t = 1 saat header terbuka penuh, 0 saat menciut jadi appbar biasa.
                  final minHeight =
                      kToolbarHeight + MediaQuery.paddingOf(context).top;
                  final t =
                      ((constraints.maxHeight - minHeight) /
                              (_headerHeight - minHeight))
                          .clamp(0.0, 1.0);
                  final base =
                      theme.appBarTheme.titleTextStyle ??
                      theme.textTheme.titleLarge!;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Foto + gradien gelap di bawah; memudar saat header menciut.
                      Opacity(
                        opacity: t,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SpotImage(spot: _spot, iconSize: 72),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.center,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Judul putih di atas foto, kembali ke warna tema saat menciut.
                      Positioned(
                        left: 16 + 40 * (1 - t),
                        right: 64,
                        bottom: 14,
                        child: Text(
                          _spot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base.copyWith(
                            color: Color.lerp(base.color, Colors.white, t),
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black.withValues(alpha: 0.6 * t),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Tombol dengan latar bulat semi-transparan agar tetap terlihat di atas foto.
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  tooltip: 'Kembali',
                  style: _overlayButtonStyle,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                  child: IconButton(
                    tooltip: isFav ? 'Hapus dari favorit' : 'Tambah ke favorit',
                    style: _overlayButtonStyle,
                    onPressed: _togglingFav ? null : _toggleFavorite,
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                  ),
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
                    // Buka Plan dengan spot ini sudah terpilih.
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlanScreen(initialSpot: _spot),
                      ),
                    ),
                    icon: const Icon(Icons.insights),
                    label: const Text('Rencanakan Foto di Sini'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    // Buka Assistant dengan konteks spot ini.
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssistantScreen(spot: _spot),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Tanya Assistant'),
                  ),
                  if (_spot.imageCredit != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Foto: ${_spot.imageCredit}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

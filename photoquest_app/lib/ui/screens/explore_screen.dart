import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/spot.dart';
import '../../providers/spot_provider.dart';
import '../widgets/spot_card.dart';
import '../widgets/state_views.dart';
import 'spot_detail_screen.dart';

/// Explore: cari spot (nama/deskripsi), filter kategori, filter favorit, pilih spot.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SpotProvider>();
    _searchCtrl = TextEditingController(text: provider.query);
    WidgetsBinding.instance.addPostFrameCallback((_) => provider.refresh());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Selection: spot yang dipilih dibawa ke halaman detail.
  void _openDetail(Spot spot) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SpotProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Explore Spot')),
      body: Column(
        children: [
          // Kolom pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau deskripsi spot',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          p.setQuery('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (v) {
                p.setQuery(v);
                setState(() {}); // tampilkan/sembunyikan tombol clear
              },
            ),
          ),
          // Chip filter kategori + favorit
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  avatar: const Icon(Icons.favorite, size: 18),
                  label: const Text('Favorit'),
                  selected: p.favoritesOnly,
                  onSelected: p.setFavoritesOnly,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: p.category == null,
                  onSelected: (_) => p.setCategory(null),
                ),
                for (final c in AppConstants.spotCategories) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(Labels.category(c)),
                    selected: p.category == c,
                    onSelected: (_) => p.setCategory(c),
                  ),
                ],
              ],
            ),
          ),
          if (p.fromCache && !p.loading) OfflineBanner(cachedAt: p.cachedAt),
          Expanded(child: _buildList(p)),
        ],
      ),
    );
  }

  Widget _buildList(SpotProvider p) {
    if (p.loading && p.spots.isEmpty) return const LoadingView();
    if (p.error != null) {
      return Center(
        child: ErrorView(message: p.error!, onRetry: p.loadSpots),
      );
    }
    final spots = p.visibleSpots;
    if (spots.isEmpty) {
      return Center(
        child: EmptyView(
          message: p.favoritesOnly
              ? 'Belum ada spot favorit yang cocok.'
              : 'Tidak ada spot yang cocok dengan pencarian.',
          icon: Icons.search_off,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: spots.length,
        itemBuilder: (_, i) {
          final s = spots[i];
          return SpotCard(
            spot: s,
            isFavorite: p.isFavorite(s.id),
            onTap: () => _openDetail(s),
          );
        },
      ),
    );
  }
}

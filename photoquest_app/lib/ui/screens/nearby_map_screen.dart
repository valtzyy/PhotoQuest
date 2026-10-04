import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/spot.dart';
import '../../data/remote/api_exception.dart';
import '../../data/repositories/spot_repository.dart';
import '../../providers/location_provider.dart';
import '../widgets/location_permission.dart';
import '../widgets/state_views.dart';
import 'spot_detail_screen.dart';

/// Peta Terdekat: peta OpenStreetMap, marker spot + posisi user,
/// daftar spot diurutkan dari yang terdekat (jarak Haversine).
class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final _mapController = MapController();
  bool _mapReady = false;

  List<Spot> _spots = [];
  bool _loadingSpots = true;
  String? _error;
  bool _fromCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadSpots();
      final loc = context.read<LocationProvider>();
      await loc.init();
      if (!mounted) return;
      await requestLocationWithRationale(context);
      _centerOnUser();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Peta selalu memakai SEMUA spot (tidak terpengaruh filter di Explore).
  Future<void> _loadSpots() async {
    setState(() {
      _loadingSpots = true;
      _error = null;
    });
    try {
      final result = await context.read<SpotRepository>().getSpots();
      if (!mounted) return;
      setState(() {
        _spots = result.data;
        _fromCache = result.fromCache;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  void _centerOnUser() {
    final p = context.read<LocationProvider>().position;
    if (p != null && _mapReady) _mapController.move(p, 13);
  }

  void _openDetail(Spot spot) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final nearest = loc.sortByDistance(_spots);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Terdekat'),
        actions: [
          IconButton(
            tooltip: 'Perbarui lokasi',
            onPressed: loc.loading
                ? null
                : () async {
                    await requestLocationWithRationale(context);
                    _centerOnUser();
                  },
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status sumber lokasi + toggle lokasi demo
          SwitchListTile(
            dense: true,
            secondary: Icon(loc.isDemo ? Icons.push_pin : Icons.gps_fixed),
            title: const Text('Gunakan lokasi demo (Tugu Jogja)'),
            subtitle: Text(
              loc.loading
                  ? 'Mencari lokasi GPS...'
                  : loc.message ?? (loc.isDemo ? 'Lokasi demo' : 'Lokasi GPS'),
            ),
            value: loc.useDemo,
            onChanged: loc.loading
                ? null
                : (v) async {
                    await loc.setUseDemo(v);
                    _centerOnUser();
                  },
          ),
          if (_fromCache) const OfflineBanner(),
          Expanded(flex: 3, child: _buildMap(loc)),
          Expanded(flex: 2, child: _buildNearestList(loc, nearest)),
        ],
      ),
    );
  }

  Widget _buildMap(LocationProvider loc) {
    final user = loc.position;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: user ?? LocationProvider.demoPoint,
        initialZoom: 12,
        minZoom: 5,
        maxZoom: 18,
        onMapReady: () {
          _mapReady = true;
          _centerOnUser();
        },
      ),
      children: [
        // Tile OpenStreetMap (gratis, tanpa API key). User-Agent wajib diisi
        // sesuai kebijakan penggunaan tile OSM.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.photoquest.app',
        ),
        MarkerLayer(
          markers: [
            for (final s in _spots)
              Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _openDetail(s), // tap marker -> detail spot
                  child: Tooltip(
                    message: s.name,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Labels.categoryIcon(s.category),
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (user != null)
              Marker(
                point: user,
                width: 44,
                height: 44,
                child: Icon(
                  loc.isDemo ? Icons.push_pin : Icons.person_pin_circle,
                  size: 44,
                  color: Colors.blue,
                ),
              ),
          ],
        ),
        // Atribusi wajib untuk data OpenStreetMap
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors'),
        ),
      ],
    );
  }

  Widget _buildNearestList(LocationProvider loc, List<Spot> nearest) {
    if (_loadingSpots) return const LoadingView();
    if (_error != null) {
      return Center(
        child: ErrorView(message: _error!, onRetry: _loadSpots),
      );
    }
    if (nearest.isEmpty) {
      return const Center(child: EmptyView(message: 'Belum ada data spot.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            loc.position == null ? 'Daftar spot' : 'Spot terdekat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: nearest.length,
            itemBuilder: (_, i) {
              final s = nearest[i];
              final d = loc.distanceTo(s);
              return ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(s.name),
                subtitle: Text(Labels.category(s.category)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d != null) Text(Formatters.distance(d)),
                    IconButton(
                      tooltip: 'Lihat di peta',
                      icon: const Icon(Icons.center_focus_strong),
                      onPressed: () => _mapController.move(
                        LatLng(s.latitude, s.longitude),
                        15,
                      ),
                    ),
                  ],
                ),
                onTap: () => _openDetail(s),
              );
            },
          ),
        ),
      ],
    );
  }
}

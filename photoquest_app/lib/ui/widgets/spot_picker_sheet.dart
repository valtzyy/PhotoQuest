import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/spot.dart';
import '../../data/remote/api_exception.dart';
import '../../data/repositories/spot_repository.dart';
import 'state_views.dart';

/// Bottom sheet untuk memilih spot (selection) dengan pencarian.
/// Mengembalikan [Spot] yang dipilih, atau null jika ditutup.
Future<Spot?> showSpotPicker(BuildContext context) =>
    showModalBottomSheet<Spot>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: 0.85, child: _SpotPicker()),
    );

class _SpotPicker extends StatefulWidget {
  const _SpotPicker();

  @override
  State<_SpotPicker> createState() => _SpotPickerState();
}

class _SpotPickerState extends State<_SpotPicker> {
  List<Spot>? _spots;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Daftar lengkap (online, atau dari cache sqflite saat offline).
      final result = await context.read<SpotRepository>().getSpots();
      if (mounted) setState(() => _spots = result.data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = (_spots ?? [])
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Cari spot',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: ErrorView(message: _error!, onRetry: _load),
                )
              : _spots == null
              ? const LoadingView()
              : filtered.isEmpty
              ? const Center(child: EmptyView(message: 'Spot tidak ditemukan.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    return ListTile(
                      leading: Icon(Labels.categoryIcon(s.category)),
                      title: Text(s.name),
                      subtitle: Text(
                        '${Labels.category(s.category)} · ${Labels.bestTime(s.bestTime)}',
                      ),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/time_zones.dart';
import '../../data/models/currency.dart';
import '../../data/models/spot.dart';
import '../../data/repositories/cached_result.dart';
import '../../data/repositories/converter_repository.dart';
import '../../providers/converter_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/weather_provider.dart';
import '../widgets/spot_picker_sheet.dart';
import '../widgets/state_views.dart';

/// Konverter untuk fotografer: harga gear (kurs) dan jadwal lintas zona waktu.
class ConverterScreen extends StatelessWidget {
  const ConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          ConverterProvider(ctx.read<ConverterRepository>())..load(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Konverter'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.currency_exchange), text: 'Kurs'),
                Tab(icon: Icon(Icons.schedule), text: 'Waktu'),
              ],
            ),
          ),
          body: const TabBarView(children: [_CurrencyTab(), _TimeTab()]),
        ),
      ),
    );
  }
}

// ======================================================================= KURS

class _CurrencyTab extends StatefulWidget {
  const _CurrencyTab();

  @override
  State<_CurrencyTab> createState() => _CurrencyTabState();
}

class _CurrencyTabState extends State<_CurrencyTab> {
  bool _manual = false;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  /// "1500000" / "83,5" / "83.5" -> double
  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ConverterProvider>();
    final theme = Theme.of(context);
    if (p.loading && p.rates == null) return const LoadingView();

    final rates = p.rates;
    return RefreshIndicator(
      onRefresh: p.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Membeli gear dari luar negeri? Bandingkan harganya dalam 4 mata uang.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (rates != null) _RateSourceCard(result: rates),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Pilih gear'),
                icon: Icon(Icons.camera_alt),
              ),
              ButtonSegment(
                value: true,
                label: Text('Input manual'),
                icon: Icon(Icons.edit),
              ),
            ],
            selected: {_manual},
            onSelectionChanged: (s) {
              setState(() => _manual = s.first);
              if (!_manual && p.gear.isNotEmpty) {
                p.selectGear(p.selectedGear ?? p.gear.first);
              } else if (_manual) {
                p.setManual(amount: _parse(_amountCtrl.text) ?? 0);
              }
            },
          ),
          const SizedBox(height: 12),
          if (!_manual) ..._gearPicker(p) else _manualInput(p),
          const SizedBox(height: 16),
          Text('Hasil konversi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final entry in p.converted.entries)
            Card(
              color: entry.key == p.currency
                  ? theme.colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: CircleAvatar(child: Text(entry.key)),
                title: Text(
                  Formatters.money(entry.value, entry.key),
                  style: theme.textTheme.titleLarge,
                ),
                subtitle: entry.key == p.currency
                    ? const Text('Harga asal')
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _gearPicker(ConverterProvider p) {
    if (p.gear.isEmpty) {
      return [
        ErrorView(
          message: p.error ?? 'Daftar gear belum tersedia.',
          onRetry: p.load,
        ),
      ];
    }
    return [
      DropdownMenu<GearItem>(
        expandedInsets: EdgeInsets.zero,
        label: const Text('Gear fotografi'),
        initialSelection: p.selectedGear,
        onSelected: p.selectGear,
        dropdownMenuEntries: [
          for (final g in p.gear)
            DropdownMenuEntry(
              value: g,
              label: '${g.name} — ${Formatters.money(g.priceIdr, 'IDR')}',
            ),
        ],
      ),
    ];
  }

  Widget _manualInput(ConverterProvider p) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Harga',
              hintText: 'mis. 199,99',
            ),
            onChanged: (v) => p.setManual(amount: _parse(v) ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: p.currency,
          items: [
            for (final c in supportedCurrencies)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (c) =>
              p.setManual(amount: _parse(_amountCtrl.text) ?? 0, currency: c),
        ),
      ],
    );
  }
}

/// Sumber & waktu kurs: live / cache / fallback.
class _RateSourceCard extends StatelessWidget {
  const _RateSourceCard({required this.result});
  final CachedResult<CurrencyRates> result;

  @override
  Widget build(BuildContext context) {
    final r = result.data;
    final offline = result.fromCache;
    final (String label, IconData icon) = r.isFallback
        ? ('Fallback (kurs tetap)', Icons.warning_amber)
        : offline
        ? ('Offline (cache)', Icons.cloud_off)
        : r.source == 'cache'
        ? ('Cache server', Icons.history)
        : ('Live', Icons.wifi);
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text('Kurs: $label'),
        subtitle: Text(
          'Frankfurter (kurs referensi ECB) tanggal ${r.date}\n'
          'Diambil ${Formatters.dateTime(r.fetchedAt)}'
          '${r.isFallback ? '\nKurs live tidak tersedia, hasil hanya perkiraan.' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ====================================================================== WAKTU

class _TimeTab extends StatefulWidget {
  const _TimeTab();

  @override
  State<_TimeTab> createState() => _TimeTabState();
}

class _TimeTabState extends State<_TimeTab> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  Spot? _spot; // null = lokasi Home (GPS terakhir / demo)

  // Konversi jam bebas
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 0);
  AppZone _fromZone = appZones.first;

  @override
  void initState() {
    super.initState();
    // Jam berjalan: perbarui tiap detik, dibatalkan di dispose().
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  (double, double) get _point {
    final s = _spot;
    if (s != null) return (s.latitude, s.longitude);
    final p =
        context.read<LocationProvider>().position ?? LocationProvider.demoPoint;
    return (p.latitude, p.longitude);
  }

  void _loadWeather() {
    final (lat, lng) = _point;
    context.read<WeatherProvider>().load(lat, lng);
  }

  Future<void> _pickSpot() async {
    final spot = await showSpotPicker(context);
    if (spot == null) return;
    setState(() => _spot = spot);
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Koordinasi jadwal pemotretan dengan klien atau rekan di zona waktu lain.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _clockCard(theme),
        const SizedBox(height: 12),
        _goldenCard(theme),
        const SizedBox(height: 12),
        _freeConvertCard(theme),
      ],
    );
  }

  Widget _clockCard(ThemeData theme) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jam sekarang', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final z in appZones)
            Builder(
              builder: (_) {
                final t = TimeZoneConverter.inZone(_now, z);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(z.label),
                  subtitle: Text(
                    '${TimeZoneConverter.offsetLabel(t, z)} · '
                    '${DateFormat('EEE, d MMM', 'id_ID').format(t)}',
                  ),
                  trailing: Text(
                    DateFormat('HH.mm.ss', 'id_ID').format(t),
                    style: theme.textTheme.titleLarge,
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );

  Widget _goldenCard(ThemeData theme) {
    final (lat, lng) = _point;
    final weather = context.watch<WeatherProvider>();
    final day = weather.resultFor(lat, lng)?.data.dayFor(_now);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Golden hour hari ini',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickSpot,
                  icon: const Icon(Icons.place, size: 18),
                  label: Text(_spot?.name ?? 'Lokasi Anda'),
                ),
              ],
            ),
            if (day == null)
              weather.isLoading(lat, lng)
                  ? const LoadingView()
                  : Text(
                      weather.errorFor(lat, lng) ??
                          'Data golden hour belum tersedia.',
                    )
            else
              Table(
                columnWidths: const {0: FlexColumnWidth(1.2)},
                children: [
                  const TableRow(
                    children: [
                      Text(
                        'Zona',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Golden pagi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Golden sore',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  for (final z in appZones)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(z.label),
                        ),
                        Text(
                          _range(
                            day.goldenMorning.start,
                            day.goldenMorning.end,
                            z,
                          ),
                        ),
                        Text(
                          _range(
                            day.goldenEvening.start,
                            day.goldenEvening.end,
                            z,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Rentang golden hour di zona [z]; tanda (+1/−1 hari) relatif ke tanggal WIB.
  String _range(DateTime start, DateTime end, AppZone z) {
    final wibStart = TimeZoneConverter.inZone(start, appZones.first);
    final s = TimeZoneConverter.inZone(start, z);
    final e = TimeZoneConverter.inZone(end, z);
    return '${TimeZoneConverter.clock(s, reference: wibStart)}–${TimeZoneConverter.clock(e)}';
  }

  Widget _freeConvertCard(ThemeData theme) {
    final instant = TimeZoneConverter.fromWallClock(
      _fromZone,
      _date,
      _time.hour,
      _time.minute,
    );
    final source = TimeZoneConverter.inZone(instant, _fromZone);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konversi jam', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('d MMM yyyy', 'id_ID').format(_date)),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (t != null) setState(() => _time = t);
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
                DropdownButton<AppZone>(
                  value: _fromZone,
                  items: [
                    for (final z in appZones)
                      DropdownMenuItem(value: z, child: Text(z.label)),
                  ],
                  onChanged: (z) => setState(() => _fromZone = z!),
                ),
              ],
            ),
            const Divider(),
            for (final z in appZones)
              Builder(
                builder: (_) {
                  final t = TimeZoneConverter.inZone(instant, z);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(z.label),
                    subtitle: Text(TimeZoneConverter.offsetLabel(t, z)),
                    trailing: Text(
                      TimeZoneConverter.clock(t, reference: source),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: z == _fromZone ? FontWeight.bold : null,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

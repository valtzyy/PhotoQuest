import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/score_result.dart';
import '../../data/models/spot.dart';
import '../../data/remote/ai_api.dart';
import '../../data/remote/api_exception.dart';
import '../../providers/weather_provider.dart';
import '../widgets/score_widgets.dart';
import '../widgets/spot_picker_sheet.dart';
import '../widgets/state_views.dart';
import 'assistant_screen.dart';

/// Pilihan cuaca di Plan. Pilihan manual menimpa data prakiraan dari API.
enum WeatherChoice {
  auto('Otomatis', null, null, Icons.cloud_sync),
  cerah('Cerah', 10, 5, Icons.wb_sunny),
  berawan('Berawan', 60, 20, Icons.cloud),
  hujan('Hujan', 95, 85, Icons.umbrella);

  const WeatherChoice(this.label, this.cloudCover, this.rainProb, this.icon);
  final String label;
  final int? cloudCover; // % tutupan awan yang dikirim ke /ai/score
  final int? rainProb; // % peluang hujan yang dikirim ke /ai/score
  final IconData icon;
}

const _photoTypes = [
  'landscape',
  'sunset',
  'street',
  'architecture',
  'portrait',
];

/// Plan (AI): pilih spot + jenis foto + waktu -> Shoot Condition Score + rekomendasi.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.initialSpot});

  final Spot? initialSpot;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Spot? _spot;
  late String _photoType;
  late DateTime _date;
  late TimeOfDay _time;
  WeatherChoice _weather = WeatherChoice.auto;

  bool _analyzing = false;
  String? _error;
  ScoreResult? _result;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _spot = widget.initialSpot;
    _photoType = _spot?.photoTypes.firstOrNull ?? 'landscape';
    // Default: jam bulat berikutnya.
    final next = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(next.year, next.month, next.day);
    _time = TimeOfDay(hour: next.hour, minute: 0);
    // Jangan memicu notifyListeners() di tengah build: tunggu frame pertama selesai.
    if (_spot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
    }
  }

  DateTime get _plannedAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  /// Cuaca spot terpilih (untuk menampilkan jam golden hour di tanggal rencana).
  void _loadWeather() {
    final s = _spot;
    if (s == null) return;
    context.read<WeatherProvider>().load(s.latitude, s.longitude);
  }

  /// Setiap input berubah -> hasil analisis lama tidak berlaku lagi.
  void _changed(VoidCallback update) {
    setState(() {
      update();
      _result = null;
      _error = null;
      _saved = false;
    });
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickSpot() async {
    final spot = await showSpotPicker(context);
    if (spot == null) return;
    _changed(() {
      _spot = spot;
      if (!spot.photoTypes.contains(_photoType) && spot.photoTypes.isNotEmpty) {
        _photoType = spot.photoTypes.first;
      }
    });
    _loadWeather();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      // Prakiraan cuaca tersedia 7 hari ke depan.
      lastDate: today.add(const Duration(days: 6)),
    );
    if (picked != null) _changed(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) _changed(() => _time = picked);
  }

  void _useTime(DateTime t) {
    final local = t.toLocal();
    _changed(() => _time = TimeOfDay(hour: local.hour, minute: local.minute));
  }

  Future<void> _analyze() async {
    final spot = _spot;
    if (spot == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
      _result = null;
      _saved = false;
    });
    try {
      final result = await context.read<AiApi>().score(
        spotId: spot.id,
        photoType: _photoType,
        plannedAt: _plannedAt,
        cloudCover: _weather.cloudCover,
        rainProb: _weather.rainProb,
      );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _save() async {
    final result = _result;
    final spot = _spot;
    if (result == null || spot == null) return;
    setState(() => _saving = true);
    try {
      await context.read<AiApi>().saveSession(
        spotId: spot.id,
        photoType: _photoType,
        plannedAt: _plannedAt,
        score: result.score,
        recommendation: result.recommendation,
      );
      if (!mounted) return;
      setState(() => _saved = true);
      _snack('Sesi foto disimpan');
    } on ApiException catch (e) {
      _snack(
        e.isNetworkError
            ? 'Sedang offline. Sesi hanya bisa disimpan saat online.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _askAssistant() {
    final result = _result;
    final spot = _spot;
    if (result == null || spot == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          spot: spot,
          planContext: {
            'photo_type': Labels.photoType(_photoType),
            'planned_at': '${Formatters.dateTime(_plannedAt)} (waktu HP)',
            'score': '${result.score}',
            'label': result.label,
            'weather':
                'awan ${result.cloudCover.round()}%, peluang hujan ${result.rainProb.round()}%',
            'golden_hour':
                'pagi ${Formatters.rangeWib(result.goldenMorning.start, result.goldenMorning.end)}, '
                'sore ${Formatters.rangeWib(result.goldenEvening.start, result.goldenEvening.end)} WIB',
          },
        ),
      ),
    );
  }

  Future<void> _showSessions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SessionsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spot = _spot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan (AI)'),
        actions: [
          IconButton(
            tooltip: 'Sesi tersimpan',
            onPressed: _showSessions,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Spot (selection)
          Text('1. Spot', style: theme.textTheme.titleSmall),
          Card(
            child: ListTile(
              leading: Icon(
                spot == null
                    ? Icons.add_location_alt
                    : Labels.categoryIcon(spot.category),
              ),
              title: Text(spot?.name ?? 'Pilih spot'),
              subtitle: spot == null
                  ? const Text('Wajib dipilih')
                  : Text('Waktu terbaik: ${Labels.bestTime(spot.bestTime)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickSpot,
            ),
          ),
          const SizedBox(height: 12),

          // 2. Jenis foto (★ = cocok dengan spot)
          Text('2. Jenis foto', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in _photoTypes)
                ChoiceChip(
                  label: Text(
                    '${Labels.photoType(t)}${spot?.photoTypes.contains(t) == true ? ' ★' : ''}',
                  ),
                  selected: _photoType == t,
                  onSelected: (_) => _changed(() => _photoType = t),
                ),
            ],
          ),
          if (spot != null)
            Text('★ cocok untuk spot ini', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),

          // 3. Waktu
          Text('3. Tanggal & jam', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('EEE, d MMM', 'id_ID').format(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          _goldenShortcuts(),
          const SizedBox(height: 12),

          // 4. Cuaca
          Text('4. Cuaca', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<WeatherChoice>(
            showSelectedIcon: false,
            segments: [
              for (final w in WeatherChoice.values)
                ButtonSegment(
                  value: w,
                  label: Text(w.label),
                  icon: Icon(w.icon),
                ),
            ],
            selected: {_weather},
            onSelectionChanged: (s) => _changed(() => _weather = s.first),
          ),
          Text(
            _weather == WeatherChoice.auto
                ? 'Memakai prakiraan awan & hujan dari Open-Meteo.'
                : 'Manual: awan ${_weather.cloudCover}%, hujan ${_weather.rainProb}% (menimpa prakiraan).',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: spot == null || _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.insights),
            label: Text(_analyzing ? 'Menganalisis...' : 'Analisis'),
          ),
          const SizedBox(height: 16),
          if (_error != null) ErrorView(message: _error!, onRetry: _analyze),
          if (_result != null) ..._buildResult(_result!),
        ],
      ),
    );
  }

  /// Info jam golden hour pada tanggal rencana + tombol pintas.
  Widget _goldenShortcuts() {
    final spot = _spot;
    if (spot == null) return const SizedBox.shrink();
    final info = context
        .watch<WeatherProvider>()
        .resultFor(spot.latitude, spot.longitude)
        ?.data;
    final day = info?.dayFor(_plannedAt);
    if (day == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.wb_twilight, size: 18),
          label: Text(
            'Golden pagi ${Formatters.rangeWib(day.goldenMorning.start, day.goldenMorning.end)}',
          ),
          onPressed: () => _useTime(day.goldenMorning.start),
        ),
        ActionChip(
          avatar: const Icon(Icons.wb_twilight, size: 18),
          label: Text(
            'Golden sore ${Formatters.rangeWib(day.goldenEvening.start, day.goldenEvening.end)}',
          ),
          onPressed: () => _useTime(day.goldenEvening.start),
        ),
      ],
    );
  }

  List<Widget> _buildResult(ScoreResult r) {
    final theme = Theme.of(context);
    final source = switch (r.conditionSource) {
      'manual' => 'pilihan manual',
      'forecast' => 'prakiraan Open-Meteo',
      _ => 'nilai default (prakiraan belum tersedia)',
    };
    return [
      Center(
        child: ScoreGauge(score: r.score, label: r.label),
      ),
      const SizedBox(height: 8),
      Text(
        'Awan ${r.cloudCover.round()}% · hujan ${r.rainProb.round()}% · $source'
        '${r.weatherSource == 'estimate' ? '\nJam golden hour memakai estimasi 05.30/17.45 WIB' : ''}',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rincian skor', style: theme.textTheme.titleMedium),
              ScoreBreakdownList(items: r.breakdown),
            ],
          ),
        ),
      ),
      RecommendationCard(recommendation: r.recommendation, isAi: r.isAi),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _saved || _saving ? null : _save,
            icon: Icon(_saved ? Icons.check : Icons.save),
            label: Text(_saved ? 'Tersimpan' : 'Simpan Sesi'),
          ),
          OutlinedButton.icon(
            // Notifikasi pengingat golden hour dibuat di Fase 9.
            onPressed: () => _snack('Pengingat (notifikasi) dibuat di Fase 9'),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Ingatkan Saya'),
          ),
          OutlinedButton.icon(
            onPressed: _askAssistant,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Tanya Assistant'),
          ),
        ],
      ),
    ];
  }
}

/// Daftar sesi foto yang pernah disimpan (GET /sessions).
class _SessionsSheet extends StatelessWidget {
  const _SessionsSheet();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PhotoSession>>(
      future: context.read<AiApi>().sessions(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorView(message: snap.error.toString());
        }
        final sessions = snap.data!;
        if (sessions.isEmpty) {
          return const EmptyView(message: 'Belum ada sesi foto tersimpan.');
        }
        return ListView(
          shrinkWrap: true,
          children: [
            for (final s in sessions)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scoreColor(s.score),
                  foregroundColor: Colors.white,
                  child: Text('${s.score}'),
                ),
                title: Text(s.spotName),
                subtitle: Text(
                  '${Labels.photoType(s.photoType)} · ${Formatters.dateTime(s.plannedAt)}',
                ),
              ),
          ],
        );
      },
    );
  }
}

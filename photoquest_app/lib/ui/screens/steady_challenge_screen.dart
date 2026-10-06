import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/sensor_math.dart';
import '../../core/steady_challenge.dart';
import '../../data/remote/api_exception.dart';
import '../../data/remote/challenge_api.dart';
import '../../providers/sensor_provider.dart';
import '../widgets/sensor_widgets.dart';
import 'chain_explorer_screen.dart';

enum _Phase { idle, countdown, running, finished }

/// Steady Shot Challenge: tahan HP rata & stabil 5 detik dalam 20 detik.
/// Hasil yang berhasil dicatat di blockchain lewat POST /challenge.
class SteadyChallengeScreen extends StatelessWidget {
  const SteadyChallengeScreen({super.key, this.createSensors});

  /// Untuk tes: sumber sensor palsu.
  final SensorProvider Function()? createSensors;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SensorProvider>(
      // dispose() otomatis saat layar ditutup -> stream sensor dibatalkan.
      create: (_) => (createSensors?.call() ?? SensorProvider())..start(),
      child: const _ChallengeView(),
    );
  }
}

class _ChallengeView extends StatefulWidget {
  const _ChallengeView();

  @override
  State<_ChallengeView> createState() => _ChallengeViewState();
}

class _ChallengeViewState extends State<_ChallengeView> {
  static const _tickMs = 100; // sampling 10× per detik

  _Phase _phase = _Phase.idle;
  int _countdown = 3;
  SteadyChallenge _game = SteadyChallenge();
  Timer? _timer;

  // Pengiriman hasil
  bool _submitting = false;
  String? _submitError;
  ChallengeSubmitResult? _submitResult;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
      _game = SteadyChallenge();
      _submitResult = null;
      _submitError = null;
    });
    // Hitung mundur 3 detik
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _run();
      }
    });
  }

  void _run() {
    context.read<SensorProvider>().resetFilters();
    setState(() => _phase = _Phase.running);
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      // Timer.periodic dijadwalkan relatif ke waktu mulai, jadi tiap tick = 100 ms.
      final sensors = context.read<SensorProvider>();
      setState(
        () =>
            _game.tick(roll: sensors.roll, shake: sensors.shake, dtMs: _tickMs),
      );
      if (_game.finished) _finish();
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.finished;
      _submitting = true;
    });
    try {
      final result = await context.read<ChallengeApi>().submit(
        success: _game.success,
        holdSeconds: _game.bestHoldSeconds,
        avgTilt: _game.avgTilt,
        avgShake: _game.avgShake,
      );
      if (mounted) setState(() => _submitResult = result);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _submitError = e.isNetworkError
              ? 'Sedang offline: hasil tidak tersimpan & tidak tercatat di blockchain.'
              : e.message,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensors = context.watch<SensorProvider>();
    final sensorError = sensors.accelError ?? sensors.gyroError;

    return Scaffold(
      appBar: AppBar(title: const Text('Steady Shot Challenge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sensorError != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.sensors_off),
                title: Text(sensorError),
                subtitle: const Text(
                  'Challenge membutuhkan accelerometer dan gyroscope.',
                ),
              ),
            )
          else
            ...switch (_phase) {
              _Phase.idle => _idle(),
              _Phase.countdown => _countdownView(),
              _Phase.running => _running(sensors),
              _Phase.finished => _result(),
            },
        ],
      ),
    );
  }

  List<Widget> _idle() => [
    const Icon(Icons.sports_esports, size: 72),
    const SizedBox(height: 12),
    Text(
      'Tahan HP tetap rata dan stabil',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 8),
    const Text(
      'Pegang HP tegak (portrait). Jaga kemiringan ≤ 2° dan getaran < 0,15 rad/s '
      'terus-menerus selama 5 detik. Waktu maksimal 20 detik. '
      'Jika keluar batas, hitungan kembali ke 0.\n\n'
      'Berhasil = hasil dicatat di blockchain PhotoQuest.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 24),
    FilledButton.icon(
      onPressed: _start,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Mulai'),
    ),
  ];

  List<Widget> _countdownView() => [
    const SizedBox(height: 80),
    Text(
      '$_countdown',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.displayLarge,
    ),
    const Text(
      'Bersiap... pegang HP dengan stabil',
      textAlign: TextAlign.center,
    ),
  ];

  List<Widget> _running(SensorProvider s) {
    final theme = Theme.of(context);
    final steady = s.isLevelNow && s.shake < SteadyChallenge.shakeLimit;
    final color = steady ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    return [
      Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Progress ring: bertambah saat stabil, kembali ke 0 jika keluar batas.
              CircularProgressIndicator(
                value: _game.progress,
                strokeWidth: 16,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${Formatters.decimal(_game.currentHoldMs / 1000, digits: 1)} / 5 dtk',
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(steady ? 'Tahan...' : 'Keluar batas!'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Sisa waktu ${(_game.remainingMs / 1000).ceil()} detik',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      BubbleLevel(roll: s.roll),
      const SizedBox(height: 8),
      Text(
        '${levelLabel(s.roll)} · ${Stability.classify(s.shake).label} '
        '(${Formatters.decimal(s.shake)} rad/s)',
        textAlign: TextAlign.center,
      ),
    ];
  }

  List<Widget> _result() {
    final theme = Theme.of(context);
    final g = _game;
    return [
      Icon(
        g.success ? Icons.emoji_events : Icons.sentiment_dissatisfied,
        size: 80,
        color: g.success ? const Color(0xFFF9A825) : theme.colorScheme.outline,
      ),
      Text(
        g.success ? 'Berhasil!' : 'Belum berhasil',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Tahan terbaik'),
              trailing: Text(
                '${Formatters.decimal(g.bestHoldSeconds, digits: 1)} dtk',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Rata-rata kemiringan'),
              trailing: Text('${Formatters.decimal(g.avgTilt, digits: 1)}°'),
            ),
            ListTile(
              leading: const Icon(Icons.vibration),
              title: const Text('Rata-rata getaran'),
              trailing: Text('${Formatters.decimal(g.avgShake)} rad/s'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_submitting)
        const Center(child: CircularProgressIndicator())
      else if (_submitError != null)
        Text(
          _submitError!,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
        )
      else if (_submitResult?.blockIndex != null)
        Card(
          color: const Color(0xFFE8F5E9),
          child: ListTile(
            leading: const Icon(Icons.link, color: Color(0xFF2E7D32)),
            title: Text(
              'Tercatat di blockchain ✓ (block #${_submitResult!.blockIndex})',
            ),
            subtitle: Text(
              'hash ${_submitResult!.blockHash!.substring(0, 16)}…',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        )
      else
        const Text(
          'Hasil tersimpan di riwayat (Profil).',
          textAlign: TextAlign.center,
        ),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.replay),
            label: const Text('Coba lagi'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChainExplorerScreen()),
            ),
            icon: const Icon(Icons.link),
            label: const Text('Chain Explorer'),
          ),
        ],
      ),
    ];
  }
}

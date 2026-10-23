import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:photoquest_app/core/steady_challenge.dart';
import 'package:photoquest_app/data/local/db_helper.dart';
import 'package:photoquest_app/data/local/quiz_dao.dart';
import 'package:photoquest_app/data/local/secure_store.dart';
import 'package:photoquest_app/data/models/chain_record.dart';
import 'package:photoquest_app/data/models/quiz_question.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/providers/sensor_provider.dart';
import 'package:photoquest_app/ui/screens/chain_explorer_screen.dart';
import 'package:photoquest_app/ui/screens/quiz_screen.dart';
import 'package:photoquest_app/ui/screens/steady_challenge_screen.dart';

const _contract = '0x1234567890abcdef1234567890abcdef12345678';
const _txHash =
    '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

ChainRecord _record(
  int attemptId,
  ChainStatus status, {
  String? error,
  bool tampered = false,
}) => ChainRecord(
  attemptId: attemptId,
  userId: 3,
  holdSeconds: tampered ? 19.99 : 5.04,
  avgTilt: 1.235,
  avgShake: 0.079,
  status: status,
  createdAt: DateTime.utc(2026, 10, 23, 1, 5, 30),
  dataHash: '0xbeef',
  txHash: status == ChainStatus.failed ? null : _txHash,
  error: error,
  chainIndex: status == ChainStatus.confirmed ? attemptId - 12 : null,
  blockNumber: status == ChainStatus.confirmed ? 5000123 : null,
  confirmedAt: status == ChainStatus.confirmed
      ? DateTime.utc(2026, 10, 23, 1, 6)
      : null,
  tampered: tampered,
  explorerUrl: status == ChainStatus.failed
      ? null
      : 'https://sepolia.etherscan.io/tx/$_txHash',
);

final _client = ApiClient(SecureStore());

/// ChallengeApi palsu: menyimpan catatan di memori, tanpa jaringan.
class _FakeChainApi extends ChallengeApi {
  _FakeChainApi({List<ChainRecord>? records})
    : records = records ?? [_record(12, ChainStatus.confirmed)],
      super(_client);

  List<ChainRecord> records;
  int submits = 0;
  int retries = 0;
  int loads = 0;
  bool tampered = false;

  /// true: panggilan chain() berikutnya mengubah semua "pending" menjadi confirmed
  /// (meniru server yang memperbarui status dari Sepolia).
  bool confirmOnNextLoad = false;

  @override
  Future<ChallengeSubmitResult> submit({
    required bool success,
    required double holdSeconds,
    required double avgTilt,
    required double avgShake,
  }) async {
    submits++;
    return ChallengeSubmitResult(
      chainStatus: success ? ChainStatus.pending : null,
    );
  }

  @override
  Future<ChainInfo> chain() async {
    loads++;
    if (confirmOnNextLoad) {
      records = [
        for (final r in records)
          r.status == ChainStatus.pending
              ? _record(r.attemptId, ChainStatus.confirmed)
              : r,
      ];
      confirmOnNextLoad = false;
    }
    return ChainInfo(
      demoMode: true,
      network: 'sepolia',
      configured: true,
      contractAddress: _contract,
      contractUrl: 'https://sepolia.etherscan.io/address/$_contract',
      records: records,
    );
  }

  @override
  Future<ChainVerification> verify() async => tampered
      ? const ChainVerification(
          valid: false,
          checked: 1,
          mismatches: [
            ChainMismatch(
              attemptId: 12,
              chainIndex: 0,
              reason: 'hold_seconds berbeda (database 19.99, on-chain 5.04)',
            ),
          ],
        )
      : ChainVerification(valid: true, checked: records.length);

  @override
  Future<int> retry() async {
    retries++;
    records = [
      for (final r in records)
        r.status == ChainStatus.failed
            ? _record(r.attemptId, ChainStatus.pending)
            : r,
    ];
    return 1;
  }

  @override
  Future<void> tamperDemo() async => tampered = true;

  @override
  Future<void> repairDemo() async => tampered = false;
}

class _FakeQuizDao extends QuizDao {
  _FakeQuizDao() : super(DbHelper.instance);

  @override
  Future<List<QuizQuestion>> randomQuestions({int count = 10}) async =>
      quizSeed.take(2).toList();
}

AccelerometerEvent _upright(double deg) {
  final r = deg * math.pi / 180;
  return AccelerometerEvent(
    9.81 * math.sin(r),
    9.81 * math.cos(r),
    0,
    DateTime(2026),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Blockchain Sepolia: model dari respons backend', () {
    test('GET /chain: catatan, status, dan info kontrak terbaca', () {
      final info = ChainInfo.fromJson({
        'demo_mode': true,
        'network': 'sepolia',
        'configured': true,
        'contract_address': _contract,
        'contract_url': 'https://sepolia.etherscan.io/address/$_contract',
        'records': [
          {
            'attempt_id': 12,
            'user_id': 3,
            'hold_seconds': 5.04,
            'avg_tilt': 1.235,
            'avg_shake': 0.079,
            'data_hash': '0xbeef',
            'tx_hash': _txHash,
            'status': 'confirmed',
            'error': null,
            'chain_index': 0,
            'block_number': 5000123,
            'confirmed_at': '2026-10-23T01:06:00.000Z',
            'created_at': '2026-10-23T01:05:30.000Z',
            'tampered': false,
            'explorer_url': 'https://sepolia.etherscan.io/tx/$_txHash',
          },
          {
            'attempt_id': 13,
            'user_id': 3,
            'hold_seconds': 6,
            'avg_tilt': 1,
            'avg_shake': 0.1,
            'data_hash': null,
            'tx_hash': null,
            'status': 'failed',
            'error': 'insufficient funds',
            'chain_index': null,
            'block_number': null,
            'confirmed_at': null,
            'created_at': '2026-10-23T02:00:00.000Z',
            'explorer_url': null,
          },
        ],
      });
      expect(info.records, hasLength(2));
      expect(info.records[0].status, ChainStatus.confirmed);
      expect(info.records[0].blockNumber, 5000123);
      expect(info.records[1].status, ChainStatus.failed);
      expect(info.records[1].holdSeconds, 6.0);
      expect(info.hasFailed, isTrue);
      expect(info.hasPending, isFalse);
    });

    test('GET /chain/verify: ketidakcocokan terbaca', () {
      final v = ChainVerification.fromJson({
        'valid': false,
        'checked': 1,
        'pending': 2,
        'failed': 0,
        'mismatches': [
          {
            'attempt_id': 12,
            'chain_index': 0,
            'reason': 'data_hash tidak cocok',
          },
        ],
      });
      expect(v.valid, isFalse);
      expect(v.pending, 2);
      expect(v.mismatches.single.chainIndex, 0);
    });

    test('Status tak dikenal dianggap pending', () {
      expect(ChainStatus.parse('???'), ChainStatus.pending);
      expect(ChainStatus.parse(null), ChainStatus.pending);
    });
  });

  group('SteadyChallenge', () {
    test('Stabil terus 5 detik -> berhasil', () {
      final g = SteadyChallenge();
      for (var i = 0; i < 50; i++) {
        g.tick(roll: 0.5, shake: 0.05, dtMs: 100);
      }
      expect(g.success, isTrue);
      expect(g.finished, isTrue);
      expect(g.bestHoldSeconds, 5.0);
      expect(g.avgTilt, closeTo(0.5, 1e-9));
    });

    test('Keluar batas -> hitungan tahan kembali ke 0', () {
      final g = SteadyChallenge();
      for (var i = 0; i < 30; i++) {
        g.tick(roll: 0, shake: 0.05, dtMs: 100);
      }
      g.tick(roll: 5, shake: 0.05, dtMs: 100); // miring 5°
      expect(g.currentHoldMs, 0);
      expect(g.bestHoldMs, 3000);
      expect(g.progress, 0);
    });

    test('Getaran ≥ 0,15 rad/s juga mereset', () {
      final g = SteadyChallenge()..tick(roll: 0, shake: 0.05, dtMs: 1000);
      g.tick(roll: 0, shake: 0.2, dtMs: 100);
      expect(g.currentHoldMs, 0);
    });

    test('Tidak pernah stabil 5 detik dalam 20 detik -> gagal', () {
      final g = SteadyChallenge();
      for (var i = 0; i < 200 && !g.finished; i++) {
        // stabil 4 detik, lalu goyang sebentar
        g.tick(roll: 0, shake: i % 41 == 40 ? 0.6 : 0.05, dtMs: 100);
      }
      expect(g.finished, isTrue);
      expect(g.success, isFalse);
      expect(g.elapsedMs, 20000);
      expect(g.bestHoldMs, lessThan(5000));
    });
  });

  group('QuizSession', () {
    test('Jawaban benar menambah skor, jawaban kedua diabaikan', () {
      final s = QuizSession(quizSeed.take(2).toList());
      expect(s.answer(s.current.answerIndex), isTrue);
      s.answer((s.current.answerIndex + 1) % 4); // diabaikan
      expect(s.score, 1);
      s.next();
      expect(s.answer((s.current.answerIndex + 1) % 4), isFalse);
      s.next();
      expect(s.finished, isTrue);
      expect(s.score, 1);
    });

    test('Seed: 12 soal, setiap jawaban valid', () {
      expect(quizSeed, hasLength(12));
      for (final q in quizSeed) {
        expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
      }
    });
  });

  testWidgets(
    'Steady Challenge: countdown -> stabil 5 dtk -> dicatat ke Sepolia (pending)',
    (tester) async {
      final api = _FakeChainApi();
      final accel = StreamController<AccelerometerEvent>.broadcast();
      final gyro = StreamController<GyroscopeEvent>.broadcast();
      await tester.pumpWidget(
        Provider<ChallengeApi>.value(
          value: api,
          child: MaterialApp(
            home: SteadyChallengeScreen(
              createSensors: () => SensorProvider(
                accelerometer: () => accel.stream,
                gyroscope: () => gyro.stream,
              ),
            ),
          ),
        ),
      );
      accel.add(_upright(0.5));
      gyro.add(GyroscopeEvent(0.01, 0, 0, DateTime(2026)));
      await tester.pump();

      await tester.tap(find.text('Mulai'));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // countdown selesai

      // Data sensor stabil terus-menerus selama challenge berjalan
      for (var i = 0; i < 52; i++) {
        accel.add(_upright(0.5));
        gyro.add(GyroscopeEvent(0.01, 0, 0, DateTime(2026)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text('Berhasil!'), findsOneWidget);
      expect(api.submits, 1);
      await tester.scrollUntilVisible(
        find.textContaining('Dicatat ke blockchain'),
        200,
      );
      expect(find.text('Dicatat ke blockchain Sepolia…'), findsOneWidget);
    },
  );

  testWidgets('PhotoQuiz: jawab 2 soal -> skor -> ulangi', (tester) async {
    await tester.pumpWidget(
      Provider<QuizDao>.value(
        value: _FakeQuizDao(),
        child: const MaterialApp(home: QuizScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Soal 1 dari 2'), findsOneWidget);

    final q1 = quizSeed[0];
    await tester.tap(find.text(q1.options[q1.answerIndex]));
    await tester.pump();
    expect(find.text('Benar!'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pump();

    final q2 = quizSeed[1];
    await tester.tap(find.text(q2.options[(q2.answerIndex + 1) % 4]));
    await tester.pump();
    expect(find.text('Kurang tepat'), findsOneWidget);
    await tester.tap(find.text('Lihat skor'));
    await tester.pump();
    expect(find.text('Skor 1 / 2'), findsOneWidget);

    await tester.tap(find.text('Ulangi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Soal 1 dari 2'), findsOneWidget);
  });

  testWidgets(
    'Chain Explorer: VALID -> manipulasi database -> INVALID -> pulihkan -> VALID',
    (tester) async {
      await tester.pumpWidget(
        Provider<ChallengeApi>.value(
          value: _FakeChainApi(),
          child: const MaterialApp(home: ChainExplorerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Catatan #0'), findsOneWidget);
      expect(find.text('Terkonfirmasi'), findsOneWidget);
      expect(find.textContaining('0xaaaaaaaa…aaaaaa'), findsOneWidget);
      expect(find.textContaining('#5000123'), findsOneWidget);

      await tester.tap(find.text('Verifikasi Chain'));
      await tester.pumpAndSettle();
      expect(find.text('VALID'), findsOneWidget);
      expect(
        find.textContaining('cocok dengan 1 catatan on-chain'),
        findsOneWidget,
      );

      await tester.tap(find.text('Demo Manipulasi Data'));
      await tester.pumpAndSettle();
      expect(find.text('INVALID'), findsOneWidget);
      expect(find.textContaining('hold_seconds berbeda'), findsWidgets);

      await tester.tap(find.text('Pulihkan'));
      await tester.pumpAndSettle();
      expect(find.text('VALID'), findsOneWidget);
    },
  );

  testWidgets('Chain Explorer: "Menunggu konfirmasi" diperbarui otomatis', (
    tester,
  ) async {
    final api = _FakeChainApi(records: [_record(12, ChainStatus.pending)]);
    await tester.pumpWidget(
      Provider<ChallengeApi>.value(
        value: api,
        child: const MaterialApp(
          home: ChainExplorerScreen(pollInterval: Duration(seconds: 1)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Menunggu konfirmasi'), findsOneWidget);
    expect(find.textContaining('Catatan baru'), findsOneWidget);

    api.confirmOnNextLoad = true; // server sudah melihat transaksi masuk blok
    await tester.pump(const Duration(seconds: 1)); // poll berjalan
    await tester.pump();
    expect(find.text('Menunggu konfirmasi'), findsNothing);
    expect(find.text('Terkonfirmasi'), findsOneWidget);
    expect(api.loads, 2);

    await tester.pumpWidget(const SizedBox()); // lepas -> timer poll dibatalkan
  });

  testWidgets('Chain Explorer: catatan gagal -> alasan tampil, kirim ulang', (
    tester,
  ) async {
    final api = _FakeChainApi(
      records: [_record(13, ChainStatus.failed, error: 'insufficient funds')],
    );
    await tester.pumpWidget(
      Provider<ChallengeApi>.value(
        value: api,
        child: const MaterialApp(
          home: ChainExplorerScreen(pollInterval: Duration(seconds: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gagal'), findsOneWidget);
    expect(find.textContaining('insufficient funds'), findsOneWidget);

    await tester.tap(find.text('Kirim ulang yang gagal'));
    await tester.pump();
    await tester.pump();
    expect(api.retries, 1);
    expect(find.text('1 catatan dikirim ulang ke Sepolia'), findsOneWidget);
    expect(find.text('Menunggu konfirmasi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chain Explorer: tombol Etherscan membuka URL transaksi', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      Provider<ChallengeApi>.value(
        value: _FakeChainApi(),
        child: MaterialApp(
          home: ChainExplorerScreen(
            opener: (u) async {
              opened.add(u);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka di Etherscan'));
    await tester.pump();
    expect(
      opened.single.toString(),
      'https://sepolia.etherscan.io/tx/$_txHash',
    );

    await tester.tap(find.text('Etherscan'));
    await tester.pump();
    expect(
      opened.last.toString(),
      'https://sepolia.etherscan.io/address/$_contract',
    );
  });
}

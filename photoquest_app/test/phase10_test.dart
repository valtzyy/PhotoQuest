import 'dart:async';
import 'dart:convert';
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
import 'package:photoquest_app/data/models/chain_block.dart';
import 'package:photoquest_app/data/models/quiz_question.dart';
import 'package:photoquest_app/data/remote/api_client.dart';
import 'package:photoquest_app/data/remote/challenge_api.dart';
import 'package:photoquest_app/providers/sensor_provider.dart';
import 'package:photoquest_app/ui/screens/chain_explorer_screen.dart';
import 'package:photoquest_app/ui/screens/quiz_screen.dart';
import 'package:photoquest_app/ui/screens/steady_challenge_screen.dart';

/// Dua blok yang DITAMBANG OLEH BACKEND (chainService.mine di Node.js).
/// Jika Dart menghitung hash yang sama, verifikasi di HP konsisten dengan server.
const _fixture = '''
[
 {"block_index":0,"timestamp":"2026-10-06T01:00:00.000Z","data":{"message":"Genesis block PhotoQuest"},
  "prev_hash":"0","nonce":279,"hash":"00bbb197722131b6ac35e101b7ec1d64be2203dbddbeebc07b7a981915152f15"},
 {"block_index":1,"timestamp":"2026-10-06T01:05:30.123Z",
  "data":{"note":"Tugu é \\"ok\\"","avg_shake":0.079,"user_id":3,"type":"steady_shot","hold_seconds":5.04,"attempt_id":12,"avg_tilt":1.235},
  "prev_hash":"00bbb197722131b6ac35e101b7ec1d64be2203dbddbeebc07b7a981915152f15",
  "nonce":116,"hash":"00b2b8f1afc2ca9e49921b08c269890770a06cc259d4bd67187f6f428a765a9a"}
]
''';

List<ChainBlock> fixtureBlocks() => (jsonDecode(_fixture) as List)
    .map((e) => ChainBlock.fromJson(e as Map<String, dynamic>))
    .toList();

final _client = ApiClient(SecureStore());

/// ChallengeApi palsu: menyimpan chain di memori, tanpa jaringan.
class _FakeChainApi extends ChallengeApi {
  _FakeChainApi() : super(_client);

  List<ChainBlock> blocks = fixtureBlocks();
  int submits = 0;

  @override
  Future<ChallengeSubmitResult> submit({
    required bool success,
    required double holdSeconds,
    required double avgTilt,
    required double avgShake,
  }) async {
    submits++;
    return ChallengeSubmitResult(
      blockIndex: success ? 7 : null,
      blockHash: success ? '00abcdef0123456789' : null,
    );
  }

  @override
  Future<ChainInfo> chain() async =>
      ChainInfo(demoMode: true, difficulty: 2, blocks: blocks);

  @override
  Future<ChainVerification> verify() async => ChainHasher.verify(blocks);

  @override
  Future<void> tamperDemo() async {
    final last = blocks.last;
    blocks = [
      ...blocks.take(blocks.length - 1),
      ChainBlock(
        blockIndex: last.blockIndex,
        timestamp: last.timestamp,
        data: {...last.data, 'hold_seconds': 99.9},
        prevHash: last.prevHash,
        hash: last.hash, // hash TIDAK dihitung ulang
        nonce: last.nonce,
      ),
    ];
  }

  @override
  Future<void> repairDemo() async => blocks = fixtureBlocks();
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

  group('Blockchain: kompatibel dengan backend', () {
    test(
      'Hash yang dihitung Dart = hash dari Node.js (walau urutan key berbeda)',
      () {
        final blocks = fixtureBlocks();
        for (final b in blocks) {
          expect(
            ChainHasher.computeHash(b),
            b.hash,
            reason: 'blok #${b.blockIndex}',
          );
        }
        expect(ChainHasher.verify(blocks).valid, isTrue);
      },
    );

    test('Data diubah -> INVALID di blok tersebut', () {
      final blocks = fixtureBlocks();
      final b = blocks[1];
      blocks[1] = ChainBlock(
        blockIndex: 1,
        timestamp: b.timestamp,
        data: {...b.data, 'hold_seconds': 99.9},
        prevHash: b.prevHash,
        hash: b.hash,
        nonce: b.nonce,
      );
      final r = ChainHasher.verify(blocks);
      expect(r.valid, isFalse);
      expect(r.brokenAt, 1);
      expect(ChainHasher.blockIntact(blocks[0]), isTrue);
      expect(ChainHasher.blockIntact(blocks[1]), isFalse);
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
    'Steady Challenge: countdown -> stabil 5 dtk -> tercatat di blockchain',
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
        find.textContaining('Tercatat di blockchain'),
        200,
      );
      expect(find.text('Tercatat di blockchain ✓ (block #7)'), findsOneWidget);
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
    'Chain Explorer: VALID -> manipulasi -> INVALID -> pulihkan -> VALID',
    (tester) async {
      await tester.pumpWidget(
        Provider<ChallengeApi>.value(
          value: _FakeChainApi(),
          child: const MaterialApp(home: ChainExplorerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Block #1'), findsOneWidget);

      await tester.tap(find.text('Verifikasi Chain'));
      await tester.pumpAndSettle();
      expect(find.text('VALID'), findsOneWidget);

      await tester.tap(find.text('Demo Manipulasi Data'));
      await tester.pumpAndSettle();
      expect(find.text('INVALID'), findsOneWidget);
      expect(find.textContaining('Blok rusak: #1'), findsOneWidget);

      await tester.tap(find.text('Pulihkan'));
      await tester.pumpAndSettle();
      expect(find.text('VALID'), findsOneWidget);
    },
  );
}

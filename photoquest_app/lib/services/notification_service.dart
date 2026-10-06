import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Hasil penjadwalan notifikasi (untuk ditampilkan ke user).
class ScheduleResult {
  const ScheduleResult.ok(this.at) : error = null;
  const ScheduleResult.fail(this.error) : at = null;

  final DateTime? at;
  final String? error;

  bool get success => error == null;
}

/// Notifikasi lokal: pengingat golden hour & notifikasi uji.
///
/// Memakai AndroidScheduleMode.inexactAllowWhileIdle sehingga TIDAK butuh izin
/// "alarm & pengingat" (exact alarm). Konsekuensinya Android boleh menggeser
/// waktu tampil beberapa saat (biasanya hanya hitungan detik–menit).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _testId = 1;
  static const reminderLead = Duration(minutes: 30);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'golden_hour', // id channel
      'Pengingat Golden Hour', // nama channel di pengaturan Android
      channelDescription: 'Pengingat jadwal pemotretan PhotoQuest',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Dipanggil sekali di main.dart (setelah tz.initializeTimeZones()).
  Future<void> init() async {
    // Zona lokal HP; jika gagal dibaca, pakai Asia/Jakarta (WIB).
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// Minta izin POST_NOTIFICATIONS (wajib di Android 13+). true = diizinkan.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? await android.areNotificationsEnabled() ?? false;
  }

  /// Waktu pengingat = waktu rencana − 30 menit; null jika sudah lewat.
  static DateTime? reminderTimeFor(DateTime plannedAt, DateTime now) {
    final at = plannedAt.subtract(reminderLead);
    return at.isAfter(now) ? at : null;
  }

  /// ID unik per spot + waktu rencana (menjadwalkan ulang rencana sama = menimpa).
  static int reminderId(int spotId, DateTime plannedAt) =>
      spotId * 1000000 + (plannedAt.millisecondsSinceEpoch ~/ 60000) % 1000000;

  Future<void> _schedule(int id, DateTime at, String title, String body) =>
      _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

  /// "Ingatkan Saya" di Plan: notifikasi 30 menit sebelum waktu rencana.
  Future<ScheduleResult> scheduleGoldenReminder({
    required int spotId,
    required String spotName,
    required DateTime plannedAt,
    required String timeLabel,
    int? score,
  }) async {
    if (!await requestPermission()) {
      return const ScheduleResult.fail(
        'Izin notifikasi ditolak. Aktifkan di Pengaturan HP.',
      );
    }
    final at = reminderTimeFor(plannedAt, DateTime.now());
    if (at == null) {
      return const ScheduleResult.fail(
        'Waktu rencana kurang dari 30 menit lagi, pengingat tidak dijadwalkan.',
      );
    }
    await _schedule(
      reminderId(spotId, plannedAt),
      at,
      '📸 30 menit lagi: $spotName',
      'Rencana foto pukul $timeLabel'
          '${score == null ? '' : ' · skor kondisi $score'}. Siapkan kamera & tripod!',
    );
    return ScheduleResult.ok(at);
  }

  /// Tombol "Uji Notifikasi (10 detik)" untuk demo.
  Future<ScheduleResult> scheduleTest() async {
    if (!await requestPermission()) {
      return const ScheduleResult.fail(
        'Izin notifikasi ditolak. Aktifkan di Pengaturan HP.',
      );
    }
    final at = DateTime.now().add(const Duration(seconds: 10));
    await _schedule(
      _testId,
      at,
      'PhotoQuest: uji notifikasi',
      'Notifikasi terjadwal berhasil. Pengingat golden hour siap dipakai!',
    );
    return ScheduleResult.ok(at);
  }
}

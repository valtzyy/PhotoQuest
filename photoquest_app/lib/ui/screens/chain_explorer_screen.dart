import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/pq_colors.dart';
import '../../data/models/chain_record.dart';
import '../../data/remote/challenge_api.dart';
import '../../providers/chain_provider.dart';
import '../widgets/glass/glass_panel.dart';
import '../widgets/glass/glass_pill.dart';
import '../widgets/glass/pq_background.dart';
import '../widgets/state_views.dart';

/// Pembuka tautan eksternal (diganti di tes).
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _defaultOpener(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Chain Explorer: transaksi Steady Challenge di blockchain Ethereum Sepolia,
/// verifikasi terhadap data on-chain, dan demo manipulasi data.
class ChainExplorerScreen extends StatelessWidget {
  const ChainExplorerScreen({
    super.key,
    this.opener = _defaultOpener,
    this.pollInterval = const Duration(seconds: 12),
  });

  final UrlOpener opener;

  /// Jeda muat ulang otomatis selama ada transaksi menunggu konfirmasi.
  final Duration pollInterval;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          ChainProvider(ctx.read<ChallengeApi>(), pollInterval: pollInterval)
            ..load(),
      child: _ExplorerView(opener: opener),
    );
  }
}

String _short(String hash) => hash.length <= 16
    ? hash
    : '${hash.substring(0, 10)}…${hash.substring(hash.length - 6)}';

Future<void> _open(BuildContext context, UrlOpener opener, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await opener(Uri.parse(url));
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Tidak dapat membuka tautan')),
    );
  }
}

class _ExplorerView extends StatelessWidget {
  const _ExplorerView({required this.opener});

  final UrlOpener opener;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChainProvider>();
    final info = p.info;

    return PqBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Chain Explorer'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: p.busy ? null : p.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Builder(
          builder: (context) {
            if (p.loading && info == null) return const LoadingView();
            if (info == null) {
              return Center(
                child: ErrorView(
                  message: p.error ?? 'Gagal memuat chain',
                  onRetry: p.load,
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: p.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _NetworkPanel(info: info, opener: opener),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: p.busy ? null : p.verify,
                    icon: p.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user),
                    label: const Text('Verifikasi Chain'),
                  ),
                  if (p.verification != null) ...[
                    const SizedBox(height: 8),
                    _VerifyBanner(result: p.verification!),
                  ] else if (p.verifyError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      p.verifyError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (info.hasFailed) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: p.busy
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final msg = await p.retry();
                              messenger.showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            },
                      icon: const Icon(Icons.replay),
                      label: const Text('Kirim ulang yang gagal'),
                    ),
                  ],
                  if (info.demoMode) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: p.busy ? null : p.tamper,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Demo Manipulasi Data'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: p.busy ? null : p.repair,
                            icon: const Icon(Icons.restore),
                            label: const Text('Pulihkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (info.records.isEmpty)
                    const EmptyView(
                      message:
                          'Belum ada catatan. Menangkan Steady Challenge untuk '
                          'mencatat hasilnya di blockchain Sepolia.',
                    ),
                  for (final r in info.records)
                    _RecordCard(
                      record: r,
                      opener: opener,
                      mismatch: p.verification?.mismatches
                          .where((m) => m.attemptId == r.attemptId)
                          .firstOrNull,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Info jaringan dan kontrak (alamat dipendekkan, tap untuk buka di Etherscan).
class _NetworkPanel extends StatelessWidget {
  const _NetworkPanel({required this.info, required this.opener});

  final ChainInfo info;
  final UrlOpener opener;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = info.contractAddress;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ethereum Sepolia (testnet)',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              GlassPill(
                label: info.configured ? 'Terhubung' : 'Belum dikonfigurasi',
                tone: info.configured ? GlassTone.green : GlassTone.red,
                icon: info.configured ? Icons.link : Icons.link_off,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${info.records.length} transaksi · hash data keccak256 · '
            'dicatat oleh smart contract ChallengeRegistry',
            style: theme.textTheme.bodySmall,
          ),
          if (address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'kontrak  ${_short(address)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                if (info.contractUrl != null)
                  TextButton.icon(
                    onPressed: () => _open(context, opener, info.contractUrl!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Etherscan'),
                  ),
              ],
            ),
          ],
          if (!info.configured) ...[
            const SizedBox(height: 4),
            Text(
              'Server belum diberi RPC, kunci, atau alamat kontrak. Hasil challenge '
              'tetap tersimpan dan dikirim ulang setelah dikonfigurasi.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// VALID (hijau) bila data database cocok dengan catatan on-chain, INVALID (merah) bila tidak.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.result});

  final ChainVerification result;

  @override
  Widget build(BuildContext context) {
    final valid = result.valid;
    final color = valid ? PqPalette.success : PqPalette.danger;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                valid ? Icons.verified : Icons.gpp_bad,
                color: color,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                valid ? 'VALID' : 'INVALID',
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valid
                ? 'Data database cocok dengan ${result.checked} catatan on-chain.'
                : '${result.mismatches.length} catatan tidak cocok dengan data on-chain '
                      '(on-chain tidak bisa diubah).',
            textAlign: TextAlign.center,
          ),
          for (final m in result.mismatches)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Catatan #${m.chainIndex}: ${m.reason}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (result.pending > 0 || result.failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${result.pending} menunggu konfirmasi, ${result.failed} gagal '
                '(belum ikut dibandingkan).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.opener,
    this.mismatch,
  });

  final ChainRecord record;
  final UrlOpener opener;

  /// Non-null bila verifikasi terakhir menemukan data tidak cocok untuk catatan ini.
  final ChainMismatch? mismatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = record;
    final broken = mismatch != null;
    final (label, tone, icon) = switch (r.status) {
      ChainStatus.confirmed => (
        'Terkonfirmasi',
        GlassTone.green,
        Icons.check_circle,
      ),
      ChainStatus.failed => ('Gagal', GlassTone.red, Icons.error),
      ChainStatus.pending => (
        'Menunggu konfirmasi',
        GlassTone.yellow,
        Icons.hourglass_top,
      ),
    };
    final time = r.confirmedAt ?? r.createdAt;

    return Card(
      shape: broken
          ? RoundedRectangleBorder(
              side: const BorderSide(color: PqPalette.danger, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.chainIndex == null
                        ? 'Catatan baru (percobaan #${r.attemptId})'
                        : 'Catatan #${r.chainIndex}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                GlassPill(label: label, tone: tone, icon: icon),
              ],
            ),
            Text(Formatters.dateTime(time)),
            const SizedBox(height: 4),
            Text(
              'Steady Shot · user #${r.userId} · tahan ${r.holdSeconds} dtk · '
              'miring ${r.avgTilt}° · getar ${r.avgShake}',
            ),
            if (broken || r.tampered) ...[
              const SizedBox(height: 4),
              Text(
                broken
                    ? 'Data database tidak cocok dengan on-chain: ${mismatch!.reason}'
                    : 'Data database sedang dimanipulasi (demo).',
                style: const TextStyle(color: PqPalette.danger),
              ),
            ],
            if (r.status == ChainStatus.failed && r.error != null) ...[
              const SizedBox(height: 4),
              Text(
                'Alasan: ${r.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 4),
            _mono('tx      ${r.txHash == null ? '-' : _short(r.txHash!)}'),
            _mono(
              'blok    ${r.blockNumber == null ? '-' : '#${r.blockNumber}'}',
            ),
            if (r.explorerUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _open(context, opener, r.explorerUrl!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Buka di Etherscan'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mono(String text) =>
      Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
}

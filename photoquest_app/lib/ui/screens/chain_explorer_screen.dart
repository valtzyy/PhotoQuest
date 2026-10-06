import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/chain_block.dart';
import '../../data/remote/challenge_api.dart';
import '../../providers/chain_provider.dart';
import '../widgets/state_views.dart';

/// Chain Explorer: daftar blok, verifikasi chain, dan demo manipulasi data.
class ChainExplorerScreen extends StatelessWidget {
  const ChainExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ChainProvider(ctx.read<ChallengeApi>())..load(),
      child: const _ExplorerView(),
    );
  }
}

String _short(String hash) => hash.length <= 16
    ? hash
    : '${hash.substring(0, 10)}…${hash.substring(hash.length - 6)}';

class _ExplorerView extends StatelessWidget {
  const _ExplorerView();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChainProvider>();
    final info = p.info;

    return Scaffold(
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${info.blocks.length} blok · proof-of-work: hash diawali '
                '"${'0' * info.difficulty}" · SHA-256',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
              if (p.serverResult != null) ...[
                const SizedBox(height: 8),
                _VerifyBanner(server: p.serverResult!, local: p.localResult),
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
              // Blok terbaru di atas
              for (final b in info.blocks.reversed)
                _BlockCard(
                  block: b,
                  broken: p.serverResult?.brokenAt == b.blockIndex,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Status VALID (hijau) / INVALID (merah) dari server, plus hasil cek ulang di HP.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.server, this.local});

  final ChainVerification server;
  final ChainVerification? local;

  @override
  Widget build(BuildContext context) {
    final valid = server.valid;
    final color = valid ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
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
          if (!valid) ...[
            const SizedBox(height: 4),
            Text(
              'Blok rusak: #${server.brokenAt} — ${server.reason}',
              textAlign: TextAlign.center,
            ),
          ],
          if (local != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cek ulang di HP (SHA-256 lokal): ${local!.valid ? 'VALID' : 'INVALID di blok #${local!.brokenAt}'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block, required this.broken});

  final ChainBlock block;
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intact = ChainHasher.blockIntact(block); // dihitung ulang di HP
    final d = block.data;
    final summary = block.isGenesis
        ? 'Genesis block'
        : 'Steady Shot · user #${d['user_id']} · tahan ${d['hold_seconds']} dtk · '
              'miring ${d['avg_tilt']}° · getar ${d['avg_shake']}';

    return Card(
      shape: broken
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC62828), width: 2),
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
                Text(
                  'Block #${block.blockIndex}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  intact ? Icons.check_circle : Icons.error,
                  color: intact
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  size: 20,
                ),
              ],
            ),
            Text(Formatters.dateTime(DateTime.parse(block.timestamp))),
            const SizedBox(height: 4),
            Text(summary),
            const SizedBox(height: 4),
            _mono('hash     ${_short(block.hash)}'),
            _mono('prev     ${_short(block.prevHash)}'),
            _mono('nonce    ${block.nonce}'),
          ],
        ),
      ),
    );
  }

  Widget _mono(String text) =>
      Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
}

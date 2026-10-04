import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/feedback_item.dart';
import '../../data/remote/api_exception.dart';
import '../../data/repositories/cached_result.dart';
import '../../data/repositories/feedback_repository.dart';
import '../widgets/state_views.dart';

/// Tab Saran & Kesan untuk mata kuliah Pemrograman Aplikasi Mobile.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saranCtrl = TextEditingController();
  final _kesanCtrl = TextEditingController();
  bool _sending = false;

  bool _loading = true;
  String? _error;
  CachedResult<List<FeedbackItem>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saranCtrl.dispose();
    _kesanCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<FeedbackRepository>().getMine();
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FeedbackRepository>().send(
        _saranCtrl.text,
        _kesanCtrl.text,
      );
      _saranCtrl.clear();
      _kesanCtrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Terima kasih! Saran & kesan terkirim')),
      );
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? v, String label) =>
      (v?.trim().isEmpty ?? true) ? '$label wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saran & Kesan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Mata kuliah Pemrograman Aplikasi Mobile',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _saranCtrl,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Saran',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => _required(v, 'Saran'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _kesanCtrl,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Kesan',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => _required(v, 'Kesan'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: const Text('Kirim'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Yang sudah dikirim', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildList(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final result = _result!;
    if (result.data.isEmpty) {
      return const EmptyView(message: 'Belum ada saran & kesan yang dikirim.');
    }
    return Column(
      children: [
        if (result.fromCache) OfflineBanner(cachedAt: result.cachedAt),
        for (final item in result.data)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.dateTime(item.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  Text('Saran: ${item.saran}'),
                  const SizedBox(height: 4),
                  Text('Kesan: ${item.kesan}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

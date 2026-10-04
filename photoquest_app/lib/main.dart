import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'data/remote/api_client.dart';

void main() {
  runApp(const PhotoQuestApp());
}

class PhotoQuestApp extends StatelessWidget {
  const PhotoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Fase 1: layar cek koneksi backend. Diganti Splash/Login di Fase 2.
      home: const HealthCheckScreen(),
    );
  }
}

/// Layar sementara Fase 1 untuk membuktikan app → backend → database terhubung.
class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await _api.health();
      setState(() => _result = data);
    } on DioException catch (e) {
      setState(() => _error = e.message ?? e.type.name);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PhotoQuest – Cek Backend')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Base URL: ${AppConfig.apiBaseUrl}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Gagal terhubung:\n$_error'),
                ),
              ),
            if (_result != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Status: ${_result!['status']}\n'
                    'Database: ${_result!['database']}\n'
                    'Waktu server: ${_result!['time']}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _check,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

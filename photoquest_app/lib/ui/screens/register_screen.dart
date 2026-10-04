import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/validators.dart';
import '../../data/remote/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../widgets/biometric_offer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Backend langsung mengembalikan token -> user otomatis login.
      await context
          .read<AuthProvider>()
          .register(_nameCtrl.text, _emailCtrl.text, _passwordCtrl.text);
      if (!mounted) return;
      await offerBiometricIfNeeded(context);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: Validators.name,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Password (min. 6 karakter)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Ulangi password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _passwordCtrl.text ? 'Password tidak sama' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _joinCode = TextEditingController();
  bool _register = false;
  bool _isMukhtar = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_email, _password, _name, _village, _joinCode]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'full_name': _name.text.trim(),
            'role': _isMukhtar ? 'mukhtar' : 'villager',
            'village_name': _village.text.trim(),
            'join_code': _joinCode.text.trim().toUpperCase(),
          },
        );
        if (mounted && auth.currentSession == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-posta adresinize gelen onay bağlantısını açın.'),
            ),
          );
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('İşlem tamamlanamadı: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bu alan zorunlu' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.holiday_village_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Muhtarım',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _register
                          ? 'Köyünüzün dijital meydanına katılın'
                          : 'Köyünüzden haberdar olun',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Ad soyad',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Köy sakini'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Muhtar'),
                            icon: Icon(Icons.badge_outlined),
                          ),
                        ],
                        selected: {_isMukhtar},
                        onSelectionChanged: (value) =>
                            setState(() => _isMukhtar = value.first),
                      ),
                      const SizedBox(height: 12),
                      if (_isMukhtar)
                        TextFormField(
                          controller: _village,
                          decoration: const InputDecoration(
                            labelText: 'Köy adı',
                          ),
                          validator: _required,
                        )
                      else
                        TextFormField(
                          controller: _joinCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Muhtardan aldığınız katılım kodu',
                          ),
                          validator: _required,
                        ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Geçerli bir e-posta girin',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'Şifre en az 6 karakter olmalı'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Hesap oluştur' : 'Giriş yap'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(
                        _register ? 'Zaten hesabım var' : 'Yeni hesap oluştur',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

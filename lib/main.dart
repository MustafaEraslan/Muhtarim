import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/config.dart';
import 'screens/auth/auth_page.dart';
import 'screens/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const MuhtarimApp());
}

class MuhtarimApp extends StatelessWidget {
  const MuhtarimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muhtarım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !AppConfig.isConfigured
          ? const _ConfigurationPage()
          : StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = Supabase.instance.client.auth.currentSession;
                return session == null ? const AuthPage() : const HomePage();
              },
            ),
    );
  }
}

class _ConfigurationPage extends StatelessWidget {
  const _ConfigurationPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.holiday_village_rounded, size: 72),
              const SizedBox(height: 20),
              Text(
                'Muhtarım',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Supabase bağlantısı bekleniyor. README içindeki kurulumu tamamlayıp uygulamayı SUPABASE_URL ve SUPABASE_ANON_KEY ile başlatın.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

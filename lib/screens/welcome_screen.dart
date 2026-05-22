import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import 'home_shell.dart';

/// First-launch entry from spec §1: Create / Login / Guest.
///
/// V1 is local-only (per spec: "No cloud required. BLE + local storage only"),
/// so Create/Login are placeholders pointing to the same Guest entry until
/// a real auth backend exists.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _enter(BuildContext context) {
    SettingsStore.instance.onboardingComplete = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _notImplemented(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label needs an account backend — V1 is local-only. '
          'Continuing as Guest for now.',
        ),
      ),
    );
    _enter(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Image.asset(
                'assets/logo/logo-with-text.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                'Smart medication management with an 8-drawer pill device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _enter(context),
                icon: const Icon(Icons.person_outline),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Continue as Guest'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _notImplemented(context, 'Login'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Login'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _notImplemented(context, 'Create account'),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

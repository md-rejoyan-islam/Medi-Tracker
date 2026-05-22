import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import 'home_shell.dart';
import 'permissions_onboarding_screen.dart';
import 'welcome_screen.dart';

/// Routes the first-launch flow:
///
/// 1. **Welcome** until the user picks Guest / Login / Register.
/// 2. **Permissions onboarding** (bKash-style) until they accept or skip
///    the notification / alarm / battery requests.
/// 3. **HomeShell** for everything afterward.
///
/// Both gates are single-flags in [SettingsStore] so we never nag the
/// user twice. The "Re-run permission setup" tile in Settings flips the
/// permissions flag back off if they want to redo it.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final s = SettingsStore.instance;
        if (!s.onboardingComplete) return const WelcomeScreen();
        if (!s.permissionsOnboardingComplete) {
          return const PermissionsOnboardingScreen();
        }
        return const HomeShell();
      },
    );
  }
}

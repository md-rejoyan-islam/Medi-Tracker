import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import 'home_shell.dart';
import 'welcome_screen.dart';

/// Reactively swaps between [WelcomeScreen] and [HomeShell] based on
/// [SettingsStore.onboardingComplete].
///
/// Keeping this swap inside the navigator (instead of doing both a state
/// update *and* a `Navigator.pushReplacement` in Welcome) avoids a race
/// where MaterialApp rebuilds mid-navigation and the pushed route is lost
/// — which is why the Login / Create buttons were ending up "blank".
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        return SettingsStore.instance.onboardingComplete
            ? const HomeShell()
            : const WelcomeScreen();
      },
    );
  }
}

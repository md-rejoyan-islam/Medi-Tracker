import 'package:flutter/material.dart';

/// MediTracker visual design system.
///
/// Brand palette inspired by the **জমির.পাতা.বাংলা** reference design:
/// bright violet (`#A855F7` / `#7C3AED`) on a deep navy-purple ground
/// (`#0E0420`), with a fuchsia secondary for pops of warm contrast.
/// Light theme keeps the same brand violet but on warm white surfaces.
/// Both schemes meet WCAG-AA contrast for body text and follow the
/// 60-30-10 rule (neutral surface / secondary / accent).
///
/// Status colours (success/warning/danger) are exposed via [AppStatusColors]
/// as a [ThemeExtension] so the Dashboard / Drawers / History / Reminder
/// screens stay tonally consistent across themes without hard-coding raw
/// `Colors.green` etc. at the call site.
class AppTheme {
  AppTheme._();

  // --- Brand seeds ------------------------------------------------------
  static const _violet = Color(0xFF7C3AED); // violet-600 — light theme
  static const _violetBright = Color(0xFFB95CF5); // bright on dark
  static const _ink = Color(0xFF1E1B3F); // deep slate-violet text
  static const _deepPurple = Color(0xFF0E0420); // near-black navy-purple

  // --- Light scheme -----------------------------------------------------
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _violet,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEDE9FE), // violet-100
    onPrimaryContainer: Color(0xFF3B0764), // violet-950
    secondary: Color(0xFFC026D3), // fuchsia-600 — vibrant accent
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFAE8FF), // fuchsia-100
    onSecondaryContainer: Color(0xFF4A044E), // fuchsia-950
    tertiary: Color(0xFFF59E0B), // amber-500 — warm CTA
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFEF3C7),
    onTertiaryContainer: Color(0xFF78350F),
    error: Color(0xFFDC2626), // red-600
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: _ink,
    onSurfaceVariant: Color(0xFF52525B), // zinc-600
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF7FF), // hint of violet tint
    surfaceContainer: Color(0xFFF5F3FF), // violet-50
    surfaceContainerHigh: Color(0xFFEDE9FE), // violet-100
    surfaceContainerHighest: Color(0xFFDDD6FE), // violet-200
    surfaceTint: _violet,
    outline: Color(0xFFCBC2D9),
    outlineVariant: Color(0xFFE5E0EF),
    shadow: Color(0xFF1E1B3F),
    scrim: Color(0xFF1E1B3F),
    inverseSurface: Color(0xFF241048),
    onInverseSurface: Color(0xFFF5F3FF),
    inversePrimary: _violetBright,
  );

  // --- Dark scheme (matches the reference screenshot) -------------------
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _violetBright,
    onPrimary: Color(0xFF240048),
    primaryContainer: Color(0xFF5B189A), // violet-800
    onPrimaryContainer: Color(0xFFEDE0FF),
    secondary: Color(0xFFE879F9), // fuchsia-400 — vibrant on dark
    onSecondary: Color(0xFF4A044E),
    secondaryContainer: Color(0xFF86198F),
    onSecondaryContainer: Color(0xFFFAE8FF),
    tertiary: Color(0xFFFBBF24), // amber-400
    onTertiary: Color(0xFF422006),
    tertiaryContainer: Color(0xFF78350F),
    onTertiaryContainer: Color(0xFFFEF3C7),
    error: Color(0xFFF87171), // red-400
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: _deepPurple,
    onSurface: Color(0xFFF3EFFF),
    onSurfaceVariant: Color(0xFFA1A1AA), // zinc-400
    surfaceContainerLowest: Color(0xFF070210),
    surfaceContainerLow: Color(0xFF180838),
    surfaceContainer: Color(0xFF241048),
    surfaceContainerHigh: Color(0xFF2E155A),
    surfaceContainerHighest: Color(0xFF3B1B6E),
    surfaceTint: _violetBright,
    outline: Color(0xFF5B4881),
    outlineVariant: Color(0xFF3B2A55),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEDE9FE),
    onInverseSurface: Color(0xFF1E1B3F),
    inversePrimary: _violet,
  );

  // --- Status colour extension -----------------------------------------
  // Kept semantic (green / amber / red) regardless of brand hue so users
  // recognise them at a glance. Container shades in dark mode are nudged
  // slightly purple-warm so they sit on the navy-purple surfaces without
  // looking out of place.
  static const _lightStatus = AppStatusColors(
    success: Color(0xFF15803D), // green-700
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: Color(0xFFD97706), // amber-600
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    danger: Color(0xFFDC2626),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFFEE2E2),
    onDangerContainer: Color(0xFF7F1D1D),
  );

  static const _darkStatus = AppStatusColors(
    success: Color(0xFF4ADE80), // green-400
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF1A3A2A), // green tinted with violet base
    onSuccessContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF422006),
    warningContainer: Color(0xFF3F2D0E),
    onWarningContainer: Color(0xFFFEF3C7),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF450A0A),
    dangerContainer: Color(0xFF3D1623),
    onDangerContainer: Color(0xFFFEE2E2),
  );

  // --- ThemeData builders ----------------------------------------------
  static ThemeData light() => _build(lightScheme, _lightStatus);
  static ThemeData dark() => _build(darkScheme, _darkStatus);

  static ThemeData _build(ColorScheme scheme, AppStatusColors status) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[status],
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return base.textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Semantic colour roles used by the dose-status UI (Taken / Late / Missed).
///
/// Resolved per theme via `Theme.of(context).extension<AppStatusColors>()!`.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer:
          Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer:
          Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
    );
  }
}

/// Convenience: `context.statusColors.success` etc.
extension AppStatusColorsX on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
}

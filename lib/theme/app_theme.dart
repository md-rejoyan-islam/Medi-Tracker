import 'package:flutter/material.dart';

/// MediTracker visual design system.
///
/// Brand palette is derived from the heart-with-pulse logo: a deep teal
/// (`#0F766E`) with a slate-navy ink (`#0F172A`) and warm off-white surface.
/// Light theme is calm and clean; dark theme uses rich navy (not pure black)
/// with brighter teal so the brand still pops. Both schemes meet WCAG-AA
/// contrast for body text and follow the 60-30-10 rule (neutral surface /
/// secondary / accent).
///
/// Status colours (success/warning/danger) are exposed via [AppStatusColors]
/// as a [ThemeExtension] so the Dashboard / Drawers / History / Reminder
/// screens stay tonally consistent across themes without hard-coding raw
/// `Colors.green` etc. at the call site.
class AppTheme {
  AppTheme._();

  // --- Brand seeds ------------------------------------------------------
  static const _brandTeal = Color(0xFF0F766E);
  static const _brandTealBright = Color(0xFF2DD4BF);
  static const _ink = Color(0xFF0F172A); // slate-900
  static const _navy = Color(0xFF0B1220); // pre-black navy

  // --- Light scheme -----------------------------------------------------
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _brandTeal,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCCFBF1),
    onPrimaryContainer: Color(0xFF042F2E),
    secondary: Color(0xFF0EA5E9), // sky-500
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE0F2FE),
    onSecondaryContainer: Color(0xFF0C4A6E),
    tertiary: Color(0xFFF59E0B), // amber-500
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFEF3C7),
    onTertiaryContainer: Color(0xFF78350F),
    error: Color(0xFFDC2626), // red-600
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: _ink,
    onSurfaceVariant: Color(0xFF475569), // slate-600
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8FAFC), // slate-50
    surfaceContainer: Color(0xFFF1F5F9), // slate-100
    surfaceContainerHigh: Color(0xFFE2E8F0), // slate-200
    surfaceContainerHighest: Color(0xFFCBD5E1), // slate-300
    surfaceTint: _brandTeal,
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8F0),
    shadow: Color(0xFF0F172A),
    scrim: Color(0xFF0F172A),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF1F5F9),
    inversePrimary: _brandTealBright,
  );

  // --- Dark scheme ------------------------------------------------------
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _brandTealBright,
    onPrimary: Color(0xFF042F2E),
    primaryContainer: Color(0xFF115E59),
    onPrimaryContainer: Color(0xFFCCFBF1),
    secondary: Color(0xFF38BDF8), // sky-400
    onSecondary: Color(0xFF082F49),
    secondaryContainer: Color(0xFF0C4A6E),
    onSecondaryContainer: Color(0xFFE0F2FE),
    tertiary: Color(0xFFFBBF24), // amber-400
    onTertiary: Color(0xFF422006),
    tertiaryContainer: Color(0xFF78350F),
    onTertiaryContainer: Color(0xFFFEF3C7),
    error: Color(0xFFF87171), // red-400
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: _navy,
    onSurface: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFF94A3B8), // slate-400
    surfaceContainerLowest: Color(0xFF050810),
    surfaceContainerLow: Color(0xFF0F172A), // slate-900
    surfaceContainer: Color(0xFF1E293B), // slate-800
    surfaceContainerHigh: Color(0xFF2C3A52),
    surfaceContainerHighest: Color(0xFF334155), // slate-700
    surfaceTint: _brandTealBright,
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF334155),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE2E8F0),
    onInverseSurface: Color(0xFF0F172A),
    inversePrimary: _brandTeal,
  );

  // --- Status colour extension -----------------------------------------
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
    successContainer: Color(0xFF14532D),
    onSuccessContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF422006),
    warningContainer: Color(0xFF78350F),
    onWarningContainer: Color(0xFFFEF3C7),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF450A0A),
    dangerContainer: Color(0xFF7F1D1D),
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

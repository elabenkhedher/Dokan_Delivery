import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

class AppTheme {
  AppTheme._();

  // ── Palette ───────────────────────────────────────────────
  static const _primary = Color(0xFF1F7A7A);
  static const _primaryDark = Color(0xFF155B5E);
  static const _primarySoft = Color(0xFFE3F1F0);
  static const _primaryMid = Color(0xFF2A9494);
  static const _accent = Color(0xFFF2A65A);
  static const _accentSoft = Color(0xFFFDEFDD);
  static const _text = Color(0xFF1E2B2F);
  static const _mutedText = Color(0xFF5B6B70);
  static const _hintText = Color(0xFF8A979B);
  static const _border = Color(0xFFE4E1DA);
  static const _background = Color(0xFFF7F5F0);
  static const _surfaceAlt = Color(0xFFEFEDE8);
  static const _error = Color(0xFFD64545);

  // ── Dark palette ─────────────────────────────────────────
  static const _darkBackground = Color(0xFF0F1A1A);
  static const _darkSurface = Color(0xFF1A2626);
  static const _darkSurfaceAlt = Color(0xFF222E2E);
  static const _darkBorder = Color(0xFF2E3D3D);
  static const _darkText = Color(0xFFE8F0F0);
  static const _darkMuted = Color(0xFF8AABAB);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: brightness,
    ).copyWith(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF1A3535) : _primarySoft,
      onPrimaryContainer: isDark ? const Color(0xFF9ADADA) : _primaryDark,
      secondary: _accent,
      onSecondary: const Color(0xFF3D2A14),
      secondaryContainer: isDark ? const Color(0xFF3D2A14) : _accentSoft,
      onSecondaryContainer: isDark ? const Color(0xFFFFD9B0) : const Color(0xFF3D2A14),
      surface: isDark ? _darkSurface : Colors.white,
      onSurface: isDark ? _darkText : _text,
      surfaceContainerHighest: isDark ? _darkSurfaceAlt : _surfaceAlt,
      error: _error,
      outline: isDark ? _darkBorder : _border,
    );

    final scaffoldBg = isDark ? _darkBackground : _background;
    final cardColor = isDark ? _darkSurface : Colors.white;
    final borderColor = isDark ? _darkBorder : _border;
    final textColor = isDark ? _darkText : _text;
    final mutedColor = isDark ? _darkMuted : _mutedText;
    final hintColor = isDark ? const Color(0xFF5A7070) : _hintText;
    final inputFill = isDark ? _darkSurfaceAlt : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textColor,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textColor, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: textColor, fontSize: 14, height: 1.4),
        bodySmall: TextStyle(color: mutedColor, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: hintColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkSurface : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textColor, size: 24),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        labelStyle: TextStyle(color: mutedColor, fontSize: 14),
        floatingLabelStyle: TextStyle(
          color: _primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: mutedColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withValues(alpha: 0.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: _primary, width: 1.5),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkSurface : Colors.white,
        indicatorColor: isDark ? const Color(0xFF1A3535) : _primarySoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? (isDark ? const Color(0xFF9ADADA) : _primaryDark)
                : mutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _primary
                : mutedColor,
            size: 23,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A3A3A) : const Color(0xFF1E2B2F),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurfaceAlt : _surfaceAlt,
        selectedColor: _primarySoft,
        labelStyle: TextStyle(color: textColor, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: borderColor),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? _darkMuted : _mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return isDark ? _darkBorder : _border;
        }),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _primarySoft,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── Gradient helpers ──────────────────────────────────────
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_primary, _primaryMid],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_primary, _primaryDark],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_accent, Color(0xFFE08540)],
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Educational Premium Theme System
/// Aesthetic: Sophisticated Study Companion
/// 
/// Principles:
/// - Bold, memorable typography as the primary design tool
/// - Refined but intentional spatial composition
/// - Smooth, purposeful animations
/// - Accessible yet visually striking
/// - Cohesive across light and dark modes

// ============================================================================
// COLOR TOKENS
// ============================================================================

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF1E293B); // Deep Slate Blue
  static const Color primaryLight = Color(0xFF334155);
  static const Color primaryDark = Color(0xFF0F172A);

  // Secondary palette
  static const Color secondary = Color(0xFFF59E0B); // Warm Amber (Action)
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark = Color(0xFFD97706);

  // Accent palette
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentLight = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0891B2);

  // Semantic colors
  static const Color success = Color(0xFF14B8A6); // Teal
  static const Color error = Color(0xFFDC2626); // Vibrant Red
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color surface = Color(0xFFFFFFFF); // Light mode
  static const Color surfaceDark = Color(0xFF0F172A); // Dark mode

  // Neutral grays
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
  static const Color scrim = Color(0xFFF8FAFC); // Near-white
  static const Color scrimDark = Color(0xFF0F172A); // Near-black

  // Component-specific
  static const Color cardBg = Color(0xFFFAFAFF); // Slightly blue-tinted white
  static const Color cardBgDark = Color(0xFF1E293B);
  static const Color correctAnswer = Color(0xFF14B8A6); // Teal
  static const Color wrongAnswer = Color(0xFFDC2626); // Red
}

// ============================================================================
// SHADOW SYSTEM
// ============================================================================

class AppShadows {
  // Soft elevation shadows for cards and containers
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> softElevated = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> crisp = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  // Dark mode shadows
  static const List<BoxShadow> softDark = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> crispDark = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];
}

// ============================================================================
// ANIMATION CURVES
// ============================================================================

class AppCurves {
  // Entrance animations
  static const Curve snappy = Curves.easeOutExpo;
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve bounce = Curves.elasticOut;

  // Standard interaction
  static const Curve responseQuick = Curves.easeOut;

  // Page transitions
  static const Curve pageTransition = Curves.easeInOutCubic;
}

// ============================================================================
// TYPOGRAPHY SYSTEM
// ============================================================================

class AppTypography {
  // Display fonts (Plus Jakarta Sans)
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
      );

  // Headlines (Plus Jakarta Sans, medium weight)
  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0,
      );

  // Body text (Inter)
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 0.15,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.1,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.1,
      );

  // Labels
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.25,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.4,
      );

  // Caption
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
        color: AppColors.textSecondary,
      );
}

// ============================================================================
// THEME DATA
// ============================================================================

class AppTheme {
  /// Light mode theme with modern educational aesthetic
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.cardBg,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.textTertiary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scrim,
      
      // ┌─ Text Theme ─────────────────────────────────────────────┐
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.textPrimary),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.textPrimary),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.textPrimary),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: AppColors.textPrimary),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
      ),

      // ┌─ App Bar ─────────────────────────────────────────────────┐
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      // ┌─ Card ────────────────────────────────────────────────────┐
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        shadowColor: Colors.transparent,
      ),

      // ┌─ Input Decoration ────────────────────────────────────────┐
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        labelStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textTertiary,
        ),
      ),

      // ┌─ Elevated Button ─────────────────────────────────────────┐
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),

      // ┌─ Outlined Button ─────────────────────────────────────────┐
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
            color: AppColors.border,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),

      // ┌─ Text Button ─────────────────────────────────────────────┐
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // ┌─ Floating Action Button ──────────────────────────────────┐
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 8,
        extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),

      // ┌─ Tab Bar ─────────────────────────────────────────────────┐
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
      ),

      // ┌─ Bottom Navigation ───────────────────────────────────────┐
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        elevation: 12,
      ),

      // ┌─ Chip ────────────────────────────────────────────────────┐
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.scrim,
        selectedColor: AppColors.primary,
        side: const BorderSide(
          color: AppColors.border,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: AppTypography.body.copyWith(
          color: AppColors.textPrimary,
        ),
      ),

      // ┌─ Progress Indicator ──────────────────────────────────────┐
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),

      // ┌─ Divider ─────────────────────────────────────────────────┐
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ┌─ List Tile ───────────────────────────────────────────────┐
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textColor: AppColors.textPrimary,
        iconColor: AppColors.primary,
        tileColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ┌─ Snackbar ────────────────────────────────────────────────┐
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: AppTypography.body.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Dark mode theme with modern educational aesthetic
  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      secondary: AppColors.secondaryLight,
      onSecondary: Colors.white,
      tertiary: AppColors.accentLight,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.cardBgDark,
      onSurface: Colors.white,
      outline: AppColors.borderDark,
      outlineVariant: AppColors.textTertiary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scrimDark,

      // ┌─ Text Theme ─────────────────────────────────────────────┐
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: Colors.white),
        displayMedium: AppTypography.displayMedium.copyWith(color: Colors.white),
        displaySmall: AppTypography.displaySmall.copyWith(color: Colors.white),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: Colors.white),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: Colors.white),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: Colors.white),
        bodyMedium: AppTypography.body.copyWith(color: Colors.white),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
        labelLarge: AppTypography.labelLarge.copyWith(color: Colors.white),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
      ),

      // ┌─ App Bar ─────────────────────────────────────────────────┐
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cardBgDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge.copyWith(
          color: Colors.white,
        ),
      ),

      // ┌─ Card ────────────────────────────────────────────────────┐
      cardTheme: CardThemeData(
        color: AppColors.cardBgDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
        shadowColor: Colors.transparent,
      ),

      // ┌─ Input Decoration ────────────────────────────────────────┐
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F2A38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDark,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        labelStyle: AppTypography.body.copyWith(
          color: AppColors.textTertiary,
        ),
        hintStyle: AppTypography.body.copyWith(
          color: const Color(0xFF64748B),
        ),
      ),

      // ┌─ Filled Button ───────────────────────────────────────────┐
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),

      // ┌─ Outlined Button ─────────────────────────────────────────┐
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(
            color: AppColors.borderDark,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ┌─ Text Button ─────────────────────────────────────────────┐
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTypography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // ┌─ Floating Action Button ──────────────────────────────────┐
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondaryLight,
        foregroundColor: Colors.white,
        elevation: 8,
      ),

      // ┌─ Tab Bar ─────────────────────────────────────────────────┐
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryLight,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.borderDark,
      ),

      // ┌─ Bottom Navigation ───────────────────────────────────────┐
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBgDark,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        elevation: 12,
      ),

      // ┌─ Chip ────────────────────────────────────────────────────┐
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1F2A38),
        selectedColor: AppColors.primaryLight,
        side: const BorderSide(
          color: AppColors.borderDark,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: AppTypography.body.copyWith(
          color: Colors.white,
        ),
        secondaryLabelStyle: AppTypography.body.copyWith(
          color: Colors.white,
        ),
      ),

      // ┌─ Progress Indicator ──────────────────────────────────────┐
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondaryLight,
        linearTrackColor: AppColors.borderDark,
        circularTrackColor: AppColors.borderDark,
      ),

      // ┌─ Divider ─────────────────────────────────────────────────┐
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),

      // ┌─ List Tile ───────────────────────────────────────────────┐
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textColor: Colors.white,
        iconColor: AppColors.primaryLight,
        tileColor: AppColors.cardBgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ┌─ Snackbar ────────────────────────────────────────────────┐
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryLight,
        contentTextStyle: AppTypography.body.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// App Color Palette
///
/// This class contains all the colors used throughout the application.
/// Colors are organized by category for easy maintenance and consistency.
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================================================
  // PRIMARY COLORS
  // ============================================================================

  /// Primary brand color - Main teal blue
  static const Color primary = Color(0xFF027A9B);

  /// Primary color 2 - Teal
  static const Color primaryColor2Teal = Color(0xFF02B3AB);

  /// Primary color 3 - Light blue
  static const Color primaryColor3 = Color(0xFF1AA2CC);

  // ============================================================================
  // SECONDARY COLORS
  // ============================================================================

  /// Secondary light color
  static const Color secondaryLight = Color(0xFF8EBFCE);
  static const Color lightGray = Color(0xFFD2D4D6);
  // ============================================================================
  // BACKGROUND COLOR
  // ============================================================================
  static const Color defaultbackground = Color(0xFFF2F9FF);

  // ============================================================================
  // TEXT COLORS
  // ============================================================================

  /// Primary text color - Black
  static const Color textBlack = Color(0xFF2D3748);

  /// Primary text color - Gray
  static const Color textGray = Color(0xFF667085);

  /// Text background color - Light gray
  static const Color textBackground = Color(0xFFF0F1F3);

  // ============================================================================
  // ALERT & STATUS COLORS
  // ============================================================================

  /// Danger/Error alert color
  static const Color dangerAlert = Color(0xFFB22222);

  /// Danger alert background color
  static const Color dangerAlertBackground = Color(0xFFF0E5E5);

  /// Danger background color
  static const Color dangerBackground = Color(0xFFFFDED5);

  /// Moderate alert/warning color
  static const Color moderate = Color(0xFFFFC700);

  /// Moderate background color
  static const Color moderateBackground = Color(0xFFFFF7D5);

  /// Mild/Success color
  static const Color mild = Color(0xFF5CC520);

  /// Mild background color
  static const Color mildBackground = Color(0xFFDFFFCC);

  // ============================================================================
  // COLOR SCHEMES
  // ============================================================================

  /// Light theme color scheme
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: primary,
    secondary: secondaryLight,
    error: dangerAlert,
    surface: textBackground,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onError: Colors.white,
    onSurface: textGray,
  );

  // ============================================================================
  // GRADIENT DEFINITIONS
  // ============================================================================

  /// Primary gradient using main brand colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryColor2Teal, primaryColor3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Alert gradient for warning states
  static const LinearGradient alertGradient = LinearGradient(
    colors: [moderate, dangerAlert],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get alert color based on severity level
  static Color getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.mild:
        return mild;
      case AlertSeverity.moderate:
        return moderate;
      case AlertSeverity.danger:
        return dangerAlert;
    }
  }

  /// Get alert background color based on severity level
  static Color getAlertBackgroundColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.mild:
        return mildBackground;
      case AlertSeverity.moderate:
        return moderateBackground;
      case AlertSeverity.danger:
        return dangerBackground;
    }
  }

  /// Get primary color variant by index
  static Color getPrimaryVariant(int index) {
    switch (index) {
      case 0:
        return primary;
      case 1:
        return primaryColor2Teal;
      case 2:
        return primaryColor3;
      default:
        return primary;
    }
  }
}

/// Alert severity levels
enum AlertSeverity { mild, moderate, danger }

/// Extension methods for Color class
extension ColorExtensions on Color {
  /// Convert color to hex string
  String toHex() => '#${value.toRadixString(16).substring(2).toUpperCase()}';

  /// Get contrasting text color (black or white)
  Color getContrastingTextColor() {
    final double luminance = computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Text styles using the app colors
class AppTextStyles {
  AppTextStyles._();

  /// Headline text style
  static const TextStyle headline = TextStyle(
    color: AppColors.textGray,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  /// Body text style
  static const TextStyle body = TextStyle(
    color: AppColors.textGray,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  /// Caption text style
  static const TextStyle caption = TextStyle(
    color: AppColors.textGray,
    fontSize: 12,
    fontWeight: FontWeight.w300,
  );

  /// Primary button text style
  static const TextStyle primaryButton = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

/// Button styles using the app colors
class AppButtonStyles {
  AppButtonStyles._();

  /// Primary button style
  static ButtonStyle get primary => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  /// Secondary button style
  static ButtonStyle get secondary => ElevatedButton.styleFrom(
    backgroundColor: AppColors.secondaryLight,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  /// Danger button style
  static ButtonStyle get danger => ElevatedButton.styleFrom(
    backgroundColor: AppColors.dangerAlert,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

/// Usage examples and documentation
class AppColorsUsage {
  /// Example of how to use colors in widgets
  static Widget exampleUsage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        children: [
          Text(
            'Primary Color Example',
            style: AppTextStyles.headline.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: AppButtonStyles.primary,
            onPressed: () {},
            child: const Text('Primary Button'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getAlertBackgroundColor(AlertSeverity.mild),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Success message',
              style: AppTextStyles.body.copyWith(
                color: AppColors.getAlertColor(AlertSeverity.mild),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

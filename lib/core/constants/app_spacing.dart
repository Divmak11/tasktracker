/// App Spacing Constants (4px base unit)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Screen padding
  static const double screenPaddingMobile = 16.0;
  static const double screenPaddingTablet = 24.0;

  // Card padding
  static const double cardPadding = 16.0;

  // List item vertical padding
  static const double listItemVertical = 12.0;

  // Button padding
  static const double buttonHorizontal = 16.0;
  static const double buttonVertical = 10.0;
}

/// App Border Radius Constants
class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double pill = 100.0; // For pill-shaped badges
  static const double full = 9999.0; // For fully rounded (circular)
}

/// App Icon Sizes
class AppIconSize {
  static const double small = 16.0;
  static const double medium = 20.0;
  static const double standard = 24.0;
  static const double large = 32.0;
}

/// App Animation Durations
class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}

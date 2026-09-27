/// Design token — spacing scale.
library;

abstract final class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Screen horizontal padding
  static const double screenPadding = 20.0;

  // Card corner radii (24–28 px per spec)
  static const double radiusCard   = 24.0;
  static const double radiusLarge  = 28.0;
  static const double radiusMedium = 16.0;
  static const double radiusSmall  = 12.0;
  static const double radiusPill   = 100.0; // fully rounded
}

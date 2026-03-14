import 'dart:math' as math;

/// Describes a device form-factor preset used when creating an AVD.
///
/// The [width] and [height] values are in pixels; [density] is the screen
/// density in dpi.
class FormFactor {
  const FormFactor({
    required this.name,
    required this.width,
    required this.height,
    required this.density,
    this.isCustom = false,
  });

  final String name;
  final int width;
  final int height;

  /// Screen density in dpi.
  final int density;

  /// When true the user fills in [width], [height], and [density] manually.
  final bool isCustom;

  /// Diagonal screen size in inches (computed from pixels + density).
  double get diagonalInches {
    if (density == 0) return 0;
    final px = (width * width + height * height).toDouble();
    return math.sqrt(px) / density;
  }

  @override
  String toString() => name;

  // ---------------------------------------------------------------------------
  // Built-in presets
  // ---------------------------------------------------------------------------

  static const phone = FormFactor(
    name: 'Phone',
    width: 1080,
    height: 2400,
    density: 420,
  );

  static const smallPhone = FormFactor(
    name: 'Small Phone',
    width: 720,
    height: 1280,
    density: 320,
  );

  static const tablet = FormFactor(
    name: 'Tablet',
    width: 1600,
    height: 2560,
    density: 240,
  );

  static const smallTablet = FormFactor(
    name: 'Small Tablet',
    width: 1200,
    height: 1920,
    density: 213,
  );

  static const foldable = FormFactor(
    name: 'Foldable',
    width: 1768,
    height: 2208,
    density: 420,
  );

  static const tv = FormFactor(
    name: 'TV (1080p)',
    width: 1920,
    height: 1080,
    density: 213,
  );

  static const wear = FormFactor(
    name: 'Wear OS',
    width: 384,
    height: 384,
    density: 320,
  );

  static const custom = FormFactor(
    name: 'Custom',
    width: 1080,
    height: 1920,
    density: 420,
    isCustom: true,
  );

  /// All built-in presets, in display order.
  static const List<FormFactor> presets = [
    phone,
    smallPhone,
    tablet,
    smallTablet,
    foldable,
    tv,
    wear,
    custom,
  ];
}

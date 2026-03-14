/// Represents an Android API level with its human-readable name.
class ApiLevel {
  const ApiLevel({required this.level, required this.name});

  final int level;
  final String name;

  /// Package-style identifier used with sdkmanager.
  /// Example: "system-images;android-34;google_apis;x86_64"
  String packageId({String tag = "google_apis", String abi = "x86_64"}) =>
      "system-images;android-$level;$tag;$abi";

  @override
  String toString() => "API $level – $name";

  // ---------------------------------------------------------------------------
  // Known API levels (newest first)
  // ---------------------------------------------------------------------------
  static const List<ApiLevel> supported = [
    ApiLevel(level: 35, name: "Android 15 (VanillaIceCream)"),
    ApiLevel(level: 34, name: "Android 14 (UpsideDownCake)"),
    ApiLevel(level: 33, name: "Android 13 (Tiramisu)"),
    ApiLevel(level: 32, name: "Android 12L (Snow Cone v2)"),
    ApiLevel(level: 31, name: "Android 12 (Snow Cone)"),
    ApiLevel(level: 30, name: "Android 11 (Red Velvet Cake)"),
    ApiLevel(level: 29, name: "Android 10 (Queen Cake)"),
    ApiLevel(level: 28, name: "Android 9 (Pie)"),
    ApiLevel(level: 27, name: "Android 8.1 (Oreo MR1)"),
    ApiLevel(level: 26, name: "Android 8.0 (Oreo)"),
  ];
}

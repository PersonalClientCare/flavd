/// Represents a single Android Virtual Device (AVD).
class AvdDevice {
  const AvdDevice({
    required this.name,
    this.device,
    this.path,
    this.target,
    this.basedOn,
    this.tagAbi,
    this.sdcard,
    this.isRunning = false,
  });

  final String name;

  /// Optional hardware profile (e.g. "pixel_6").
  final String? device;

  /// Absolute path to the .avd directory.
  final String? path;

  /// Target string (e.g. "Google APIs (Google Inc.)").
  final String? target;

  /// Android version string (e.g. "Android 14.0 (UpsideDownCake)").
  final String? basedOn;

  /// Tag/ABI string (e.g. "google_apis/x86_64").
  final String? tagAbi;

  /// SD card size string (e.g. "512 MB").
  final String? sdcard;

  /// Whether the emulator is currently running.
  final bool isRunning;

  AvdDevice copyWith({
    String? name,
    String? device,
    String? path,
    String? target,
    String? basedOn,
    String? tagAbi,
    String? sdcard,
    bool? isRunning,
  }) {
    return AvdDevice(
      name: name ?? this.name,
      device: device ?? this.device,
      path: path ?? this.path,
      target: target ?? this.target,
      basedOn: basedOn ?? this.basedOn,
      tagAbi: tagAbi ?? this.tagAbi,
      sdcard: sdcard ?? this.sdcard,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  String toString() => "AvdDevice(name: $name, running: $isRunning)";
}

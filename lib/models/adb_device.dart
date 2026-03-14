/// Represents a physical Android device connected via ADB.
class AdbDevice {
  const AdbDevice({
    required this.serial,
    this.model,
    this.product,
    this.transportId,
    this.state = AdbDeviceState.device,
  });

  /// The device serial / address (e.g. "192.168.1.42:5555" or "RZCW30…").
  final String serial;

  /// Model name reported by ADB (e.g. "Pixel_6").
  final String? model;

  /// Product name reported by ADB (e.g. "oriole").
  final String? product;

  /// ADB transport ID.
  final String? transportId;

  /// Current device state.
  final AdbDeviceState state;

  /// Whether this device is connected over TCP/IP (wireless).
  bool get isWireless => RegExp(r"^\d+\.\d+\.\d+\.\d+:\d+$").hasMatch(serial);

  /// A human-friendly display name.
  String get displayName {
    if (model != null && model!.isNotEmpty) return model!;
    return serial;
  }

  AdbDevice copyWith({
    String? serial,
    String? model,
    String? product,
    String? transportId,
    AdbDeviceState? state,
  }) {
    return AdbDevice(
      serial: serial ?? this.serial,
      model: model ?? this.model,
      product: product ?? this.product,
      transportId: transportId ?? this.transportId,
      state: state ?? this.state,
    );
  }

  @override
  String toString() =>
      "AdbDevice(serial: $serial, model: $model, state: $state)";
}

/// Possible states for an ADB device.
enum AdbDeviceState {
  /// Device is online and available.
  device,

  /// Device is in recovery mode.
  recovery,

  /// Device is connected but not authorised (check the phone screen).
  unauthorized,

  /// Device is offline.
  offline,

  /// Unknown / unrecognised state.
  unknown;

  /// Parses the state string from `adb devices -l` output.
  static AdbDeviceState fromString(String s) {
    return switch (s.trim().toLowerCase()) {
      "device" => AdbDeviceState.device,
      "recovery" => AdbDeviceState.recovery,
      "unauthorized" => AdbDeviceState.unauthorized,
      "offline" => AdbDeviceState.offline,
      _ => AdbDeviceState.unknown,
    };
  }

  /// Human-readable label.
  String get label => switch (this) {
    AdbDeviceState.device => "Online",
    AdbDeviceState.recovery => "Recovery",
    AdbDeviceState.unauthorized => "Unauthorized",
    AdbDeviceState.offline => "Offline",
    AdbDeviceState.unknown => "Unknown",
  };
}

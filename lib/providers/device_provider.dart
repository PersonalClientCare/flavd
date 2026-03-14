import "dart:async";

import "package:flutter/foundation.dart";

import "package:flavd/models/adb_device.dart";
import "package:flavd/models/avd_device.dart";
import "package:flavd/models/form_factor.dart";
import "package:flavd/services/avd_service.dart";
import "package:flavd/services/sdk_installer_service.dart";

/// Application-wide state for AVD management.
class DeviceProvider extends ChangeNotifier {
  DeviceProvider({
    required AvdService avdService,
    required SdkInstallerService sdkInstaller,
  }) : _avdService = avdService,
       _sdkInstaller = sdkInstaller;

  final AvdService _avdService;
  final SdkInstallerService _sdkInstaller;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _sdkReady = false;
  bool get sdkReady => _sdkReady;

  bool _sdkChecked = false;
  bool get sdkChecked => _sdkChecked;

  bool _installing = false;
  bool get installing => _installing;

  double _installProgress = 0;
  double get installProgress => _installProgress;

  String _installMessage = "";
  String get installMessage => _installMessage;

  bool _loading = false;
  bool get loading => _loading;

  List<AvdDevice> _devices = [];
  List<AvdDevice> get devices => List.unmodifiable(_devices);

  List<AdbDevice> _adbDevices = [];
  List<AdbDevice> get adbDevices => List.unmodifiable(_adbDevices);

  String? _error;
  String? get error => _error;

  // Log lines produced during create/install.
  final List<String> _logLines = [];
  List<String> get logLines => List.unmodifiable(_logLines);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Detects SDK tools and loads the device list.  Call once at startup.
  Future<void> init() async {
    _setLoading(true);
    _sdkReady = await _avdService.detectTools();
    _sdkChecked = true;
    if (_sdkReady) {
      await _loadDevices();
      await _loadAdbDevices();
    }
    _setLoading(false);
  }

  // ---------------------------------------------------------------------------
  // SDK installation
  // ---------------------------------------------------------------------------

  /// Downloads and installs the Android SDK into the standard SDK directory.
  Future<void> installSdk() async {
    _installing = true;
    _installMessage = "Starting installation…";
    _installProgress = 0;
    notifyListeners();

    try {
      await _sdkInstaller.installSdk((msg, progress) {
        _installMessage = msg;
        _installProgress = progress;
        notifyListeners();
      });

      // Re-detect tools after installation.
      _sdkReady = await _avdService.detectTools();
      if (_sdkReady) {
        await _loadDevices();
        await _loadAdbDevices();
      }
    } on AvdException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// Refreshes both the AVD and physical device lists.
  Future<void> refresh() async {
    _setLoading(true);
    await _loadDevices();
    await _loadAdbDevices();
    _setLoading(false);
  }

  Future<void> _loadDevices() async {
    try {
      _devices = await _avdService.listAvds();
      _error = null;
    } on AvdException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _loadAdbDevices() async {
    try {
      _adbDevices = await _avdService.listAdbDevices();
    } on AvdException catch (e) {
      debugPrint("[_loadAdbDevices] AvdException: ${e.message}");
    } catch (e) {
      debugPrint("[_loadAdbDevices] Unexpected error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  Future<void> startDevice(String name, {bool coldBoot = false}) async {
    debugPrint("[startDevice] called with name=$name, coldBoot=$coldBoot");
    try {
      await _avdService.startAvd(name, coldBoot: coldBoot);
      // Give the emulator a moment to register, then refresh.
      await Future<void>.delayed(const Duration(seconds: 2));
      await refresh();
    } on AvdException catch (e) {
      debugPrint("[startDevice] AvdException: ${e.message}");
      _error = e.message;
      notifyListeners();
    } catch (e, st) {
      debugPrint("[startDevice] Unexpected error: $e");
      debugPrint("[startDevice] Stack: $st");
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopDevice(String name) async {
    try {
      await _avdService.stopAvd(name);
      await Future<void>.delayed(const Duration(seconds: 1));
      await refresh();
    } on AvdException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteDevice(String name) async {
    try {
      await _avdService.deleteAvd(name);
      _devices.removeWhere((d) => d.name == name);
      notifyListeners();
    } on AvdException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  Future<bool> createDevice({
    required String name,
    required int apiLevel,
    required FormFactor formFactor,
    int? customWidth,
    int? customHeight,
    int? customDensity,
    String tag = "google_apis",
    String abi = "x86_64",
  }) async {
    _logLines.clear();
    notifyListeners();

    try {
      await _avdService.createAvd(
        name: name,
        apiLevel: apiLevel,
        formFactor: formFactor,
        customWidth: customWidth,
        customHeight: customHeight,
        customDensity: customDensity,
        tag: tag,
        abi: abi,
        onLog: _appendLog,
      );
      await refresh();
      return true;
    } on AvdException catch (e) {
      _error = e.message;
      _appendLog("Error: ${e.message}");
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _appendLog("Error: $e");
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Wireless ADB – pair / connect / disconnect
  // ---------------------------------------------------------------------------

  /// Pairs with a device using Android 11+ wireless debugging.
  ///
  /// [host] is the IP address, [port] is the pairing port shown on the phone,
  /// and [code] is the 6-digit pairing code.
  Future<String> pairDevice({
    required String host,
    required int port,
    required String code,
  }) async {
    try {
      final result = await _avdService.pairDevice(
        host: host,
        port: port,
        code: code,
      );
      await refresh();
      return result;
    } on AvdException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Connects to a device over TCP/IP wireless ADB.
  Future<String> connectDevice({
    required String host,
    required int port,
  }) async {
    try {
      final result = await _avdService.connectDevice(host: host, port: port);
      await refresh();
      return result;
    } on AvdException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnects a wireless ADB device by its serial (e.g. "192.168.1.42:5555").
  Future<void> disconnectDevice(String serial) async {
    try {
      await _avdService.disconnectDevice(serial);
      _adbDevices.removeWhere((d) => d.serial == serial);
      notifyListeners();
      // Full refresh to get accurate state.
      await refresh();
    } on AvdException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _appendLog(String line) {
    _logLines.add(line);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/avd_device.dart';
import '../models/form_factor.dart';
import '../services/avd_service.dart';
import '../services/sdk_installer_service.dart';

/// Application-wide state for AVD management.
class DeviceProvider extends ChangeNotifier {
  DeviceProvider({
    required AvdService avdService,
    required SdkInstallerService sdkInstaller,
  })  : _avdService = avdService,
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

  String _installMessage = '';
  String get installMessage => _installMessage;

  bool _loading = false;
  bool get loading => _loading;

  List<AvdDevice> _devices = [];
  List<AvdDevice> get devices => List.unmodifiable(_devices);

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
    }
    _setLoading(false);
  }

  // ---------------------------------------------------------------------------
  // SDK installation
  // ---------------------------------------------------------------------------

  /// Downloads and installs the Android SDK into `~/.flavd/android-sdk`.
  Future<void> installSdk() async {
    _installing = true;
    _installMessage = 'Starting installation…';
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

  /// Refreshes the device list.
  Future<void> refresh() async {
    _setLoading(true);
    await _loadDevices();
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

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  Future<void> startDevice(String name) async {
    try {
      await _avdService.startAvd(name);
      // Give the emulator a moment to register, then refresh.
      await Future<void>.delayed(const Duration(seconds: 2));
      await refresh();
    } on AvdException catch (e) {
      _error = e.message;
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
    String tag = 'google_apis',
    String abi = 'x86_64',
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
      _appendLog('Error: ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _appendLog('Error: $e');
      notifyListeners();
      return false;
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

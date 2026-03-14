import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

import "../models/avd_device.dart";
import "../models/form_factor.dart";

/// Wraps the Android command-line tools (`avdmanager`, `emulator`, `sdkmanager`).
///
/// All methods throw [AvdException] on failure.
class AvdService {
  // Resolved binary paths (null until [detectTools] has been called).
  String? avdManagerPath;
  String? emulatorPath;
  String? sdkManagerPath;
  String? adbPath;

  bool get isAvailable =>
      avdManagerPath != null && emulatorPath != null;

  // ---------------------------------------------------------------------------
  // Tool detection
  // ---------------------------------------------------------------------------

  /// Searches the system for the required command-line tool binaries and stores
  /// their paths.  Returns `true` when at least `avdmanager` and `emulator`
  /// were found.
  Future<bool> detectTools() async {
    avdManagerPath = await _findBinary("avdmanager");
    emulatorPath = await _findBinary("emulator");
    sdkManagerPath = await _findBinary("sdkmanager");
    adbPath = await _findBinary("adb");
    return isAvailable;
  }

  Future<String?> _findBinary(String name) async {
    // 1. Check PATH.
    final which = Platform.isWindows ? "where" : "which";
    final result = await Process.run(which, [name]);
    if (result.exitCode == 0) {
      final out = result.stdout.toString().trim();
      if (out.isNotEmpty) return out.split("\n").first.trim();
    }

    // 2. Check known SDK locations.
    final sdkRoot = _sdkRoot;
    if (sdkRoot != null) {
      final ext = Platform.isWindows ? ".bat" : "";
      final candidates = [
        p.join(sdkRoot, "cmdline-tools", "latest", "bin", "$name$ext"),
        p.join(sdkRoot, "cmdline-tools", "bin", "$name$ext"),
        p.join(sdkRoot, "tools", "bin", "$name$ext"),
        p.join(sdkRoot, "emulator", '$name${Platform.isWindows ? ".exe" : ""}'),
        p.join(sdkRoot, "platform-tools", '$name${Platform.isWindows ? ".exe" : ""}'),
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
    }

    // 3. Check flavd-managed SDK location.
    final flavdSdk = _flavdSdkRoot;
    final ext = Platform.isWindows ? ".bat" : "";
    final managed = [
      p.join(flavdSdk, "cmdline-tools", "latest", "bin", "$name$ext"),
      p.join(flavdSdk, "emulator", '$name${Platform.isWindows ? ".exe" : ""}'),
      p.join(flavdSdk, "platform-tools", '$name${Platform.isWindows ? ".exe" : ""}'),
    ];
    for (final c in managed) {
      if (File(c).existsSync()) return c;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // List devices
  // ---------------------------------------------------------------------------

  /// Returns all AVDs registered on this machine.
  Future<List<AvdDevice>> listAvds() async {
    _requireAvdManager();
    final result = await Process.run(avdManagerPath!, ["list", "avd", "-c"]);
    // "-c" (compact) prints one name per line — we also run the verbose form
    // for details.
    final detailResult =
        await Process.run(avdManagerPath!, ["list", "avd"]);
    if (detailResult.exitCode != 0) {
      throw AvdException(
          "avdmanager list avd failed: ${detailResult.stderr}");
    }

    final names = result.exitCode == 0
        ? result.stdout
            .toString()
            .split("\n")
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toSet()
        : <String>{};

    final devices = _parseAvdListOutput(detailResult.stdout.toString());

    // Merge with compact list to ensure we don't miss any.
    for (final name in names) {
      if (!devices.any((d) => d.name == name)) {
        devices.add(AvdDevice(name: name));
      }
    }

    // Mark running devices.
    final running = await _runningEmulatorNames();
    return devices
        .map((d) => d.copyWith(isRunning: running.contains(d.name)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  /// Launches the AVD with [name] in a detached emulator process.
  Future<void> startAvd(String name) async {
    _requireEmulator();
    // Use Process.start so the emulator runs independently.
    await Process.start(
      emulatorPath!,
      ["-avd", name],
      mode: ProcessStartMode.detached,
    );
  }

  /// Sends a kill signal to the running emulator for [name].
  Future<void> stopAvd(String name) async {
    if (adbPath == null) {
      throw const AvdException("adb not found – cannot stop emulator.");
    }
    final port = await _portForEmulator(name);
    if (port == null) {
      throw AvdException('No running emulator found for "$name".');
    }
    await _runChecked(adbPath!, ["-s", "emulator-$port", "emu", "kill"]);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Permanently deletes the AVD with [name].
  Future<void> deleteAvd(String name) async {
    _requireAvdManager();
    await _runChecked(avdManagerPath!, ["delete", "avd", "-n", name]);
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new AVD.
  ///
  /// If the system image for [apiLevel] with [tag]/[abi] is not installed, this
  /// method will install it first via sdkmanager (writes progress to
  /// [onLog]).
  Future<void> createAvd({
    required String name,
    required int apiLevel,
    required FormFactor formFactor,
    int? customWidth,
    int? customHeight,
    int? customDensity,
    String tag = "google_apis",
    String abi = "x86_64",
    void Function(String line)? onLog,
  }) async {
    _requireAvdManager();

    final pkg = "system-images;android-$apiLevel;$tag;$abi";

    // 1. Ensure the system image is installed.
    if (!await isSystemImageInstalled(apiLevel, tag, abi)) {
      onLog?.call('System image "$pkg" not found – installing…');
      await installSystemImage(
          apiLevel: apiLevel, tag: tag, abi: abi, onLog: onLog);
    }

    // 2. Create the AVD.
    onLog?.call('Creating AVD "$name"…');
    final createResult = await _runWithInput(
      avdManagerPath!,
      ["create", "avd", "--name", name, "--package", pkg, "--force"],
      input: "\n", // Accept default when prompted "Do you want to create a custom profile?"
    );
    if (createResult.exitCode != 0) {
      throw AvdException("Failed to create AVD: ${createResult.stderr}");
    }

    // 3. Apply form-factor overrides to config.ini.
    final width = formFactor.isCustom ? (customWidth ?? formFactor.width) : formFactor.width;
    final height = formFactor.isCustom ? (customHeight ?? formFactor.height) : formFactor.height;
    final density = formFactor.isCustom ? (customDensity ?? formFactor.density) : formFactor.density;

    await _applyFormFactor(name, width, height, density, onLog);
    onLog?.call('Done – AVD "$name" created successfully.');
  }

  // ---------------------------------------------------------------------------
  // System-image helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when the system image package is installed.
  Future<bool> isSystemImageInstalled(
      int apiLevel, String tag, String abi) async {
    if (sdkManagerPath == null) return false;
    final result = await Process.run(
        sdkManagerPath!, ["--list_installed", "--verbose"]);
    if (result.exitCode != 0) return false;
    final pkg = "system-images;android-$apiLevel;$tag;$abi";
    return result.stdout.toString().contains(pkg);
  }

  /// Downloads and installs the requested system image.
  Future<void> installSystemImage({
    required int apiLevel,
    String tag = "google_apis",
    String abi = "x86_64",
    void Function(String line)? onLog,
  }) async {
    if (sdkManagerPath == null) {
      throw const AvdException("sdkmanager not found – cannot install system image.");
    }
    final pkg = "system-images;android-$apiLevel;$tag;$abi";
    onLog?.call("Installing $pkg …");

    // Accept all licenses first.
    await _runWithInput(sdkManagerPath!, ["--licenses"],
        input: "y\n" * 20);

    final result = await _runStreamed(
      sdkManagerPath!,
      [pkg],
      onLine: onLog,
      env: _sdkEnv,
    );
    if (result != 0) {
      throw AvdException("sdkmanager failed to install $pkg.");
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _requireAvdManager() {
    if (avdManagerPath == null) {
      throw const AvdException(
          "avdmanager not found. Please install the Android SDK command-line tools.");
    }
  }

  void _requireEmulator() {
    if (emulatorPath == null) {
      throw const AvdException("emulator not found.");
    }
  }

  String? get _sdkRoot =>
      Platform.environment["ANDROID_HOME"] ??
      Platform.environment["ANDROID_SDK_ROOT"];

  String get _flavdSdkRoot {
    final home =
        Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"] ?? ".";
    return p.join(home, ".flavd", "android-sdk");
  }

  Map<String, String> get _sdkEnv {
    final env = Map<String, String>.from(Platform.environment);
    final root = _sdkRoot ?? _flavdSdkRoot;
    env["ANDROID_HOME"] = root;
    env["ANDROID_SDK_ROOT"] = root;
    return env;
  }

  Future<ProcessResult> _runChecked(String exe, List<String> args) async {
    final result = await Process.run(exe, args, environment: _sdkEnv);
    if (result.exitCode != 0) {
      throw AvdException('$exe ${args.join(' ')} failed:\n${result.stderr}');
    }
    return result;
  }

  Future<ProcessResult> _runWithInput(String exe, List<String> args,
      {required String input}) async {
    final process = await Process.start(exe, args, environment: _sdkEnv);
    process.stdin.write(input);
    await process.stdin.close();
    final stdout = await process.stdout.transform(systemEncoding.decoder).join();
    final stderr = await process.stderr.transform(systemEncoding.decoder).join();
    final code = await process.exitCode;
    return ProcessResult(process.pid, code, stdout, stderr);
  }

  /// Runs [exe] with [args] and streams each output line to [onLine].
  /// Returns exit code.
  Future<int> _runStreamed(
    String exe,
    List<String> args, {
    void Function(String line)? onLine,
    Map<String, String>? env,
  }) async {
    final process = await Process.start(exe, args, environment: env);
    await process.stdin.close();

    final stdoutSub = process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen(onLine ?? (_) {});
    final stderrSub = process.stderr
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen(onLine ?? (_) {});

    final code = await process.exitCode;
    await stdoutSub.cancel();
    await stderrSub.cancel();
    return code;
  }

  /// Writes form-factor settings into the AVD's config.ini.
  Future<void> _applyFormFactor(String avdName, int width, int height,
      int density, void Function(String)? onLog) async {
    final home =
        Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"] ?? ".";
    final configPath =
        p.join(home, ".android", "avd", "$avdName.avd", "config.ini");
    final file = File(configPath);
    if (!file.existsSync()) {
      onLog?.call(
          "Warning: config.ini not found at $configPath – skipping form-factor override.");
      return;
    }

    var contents = file.readAsStringSync();

    void setKey(String key, String value) {
      final pattern = RegExp("^$key=.*", multiLine: true);
      if (pattern.hasMatch(contents)) {
        contents = contents.replaceAll(pattern, "$key=$value");
      } else {
        contents += "\n$key=$value\n";
      }
    }

    setKey("hw.lcd.width", "$width");
    setKey("hw.lcd.height", "$height");
    setKey("hw.lcd.density", "$density");
    setKey("skin.name", "${width}x$height");

    file.writeAsStringSync(contents);
    onLog?.call("Applied form-factor: ${width}x$height @ ${density}dpi");
  }

  // ---------------------------------------------------------------------------
  // Parsing avdmanager list avd output
  // ---------------------------------------------------------------------------

  @visibleForTesting
  List<AvdDevice> parseAvdListOutput(String output) => _parseAvdListOutput(output);

  List<AvdDevice> _parseAvdListOutput(String output) {
    final devices = <AvdDevice>[];

    // Each device block starts with "    Name:" and ends at "----..." or EOF.
    final blocks = output.split(RegExp(r"-{2,}"));
    for (final block in blocks) {
      final name = _extractField(block, "Name");
      if (name == null) continue;
      devices.add(AvdDevice(
        name: name,
        device: _extractField(block, "Device"),
        path: _extractField(block, "Path"),
        target: _extractField(block, "Target"),
        basedOn: _extractBasedOn(block),
        tagAbi: _extractTagAbi(block),
        sdcard: _extractField(block, "Sdcard"),
      ));
    }
    return devices;
  }

  String? _extractField(String block, String key) {
    final match =
        RegExp("^\\s*$key:\\s*(.+)", multiLine: true).firstMatch(block);
    return match?.group(1)?.trim();
  }

  String? _extractBasedOn(String block) {
    final match =
        RegExp(r"Based on:\s*([^T]+)", multiLine: true).firstMatch(block);
    return match?.group(1)?.trim();
  }

  String? _extractTagAbi(String block) {
    final match =
        RegExp(r"Tag/ABI:\s*(\S+)", multiLine: true).firstMatch(block);
    return match?.group(1)?.trim();
  }

  // ---------------------------------------------------------------------------
  // Running emulator detection
  // ---------------------------------------------------------------------------

  Future<Set<String>> _runningEmulatorNames() async {
    if (adbPath == null) return {};
    final result = await Process.run(adbPath!, ["devices", "-l"]);
    if (result.exitCode != 0) return {};
    final names = <String>{};
    for (final line in result.stdout.toString().split("\n")) {
      final match = RegExp(r"^emulator-(\d+)\s").firstMatch(line);
      if (match == null) continue;
      final port = int.tryParse(match.group(1)!);
      if (port == null) continue;
      final name = await _emulatorNameForPort(port);
      if (name != null) names.add(name);
    }
    return names;
  }

  Future<String?> _emulatorNameForPort(int port) async {
    if (adbPath == null) return null;
    final result = await Process.run(adbPath!,
        ["-s", "emulator-$port", "emu", "avd", "name"]);
    if (result.exitCode != 0) return null;
    final lines = result.stdout
        .toString()
        .split("\n")
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isNotEmpty ? lines.first : null;
  }

  Future<int?> _portForEmulator(String name) async {
    if (adbPath == null) return null;
    final result = await Process.run(adbPath!, ["devices", "-l"]);
    if (result.exitCode != 0) return null;
    for (final line in result.stdout.toString().split("\n")) {
      final match = RegExp(r"^emulator-(\d+)\s").firstMatch(line);
      if (match == null) continue;
      final port = int.tryParse(match.group(1)!);
      if (port == null) continue;
      final n = await _emulatorNameForPort(port);
      if (n == name) return port;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Exception type
// ---------------------------------------------------------------------------

class AvdException implements Exception {
  const AvdException(this.message);
  final String message;
  @override
  String toString() => "AvdException: $message";
}

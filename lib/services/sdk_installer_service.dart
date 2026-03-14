import "dart:async";
import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;

import "avd_service.dart";

/// Downloads and installs the Android SDK command-line tools into the
/// standard Android SDK directory when the SDK is not already present on the
/// system.
class SdkInstallerService {
  // Command-line tools download URLs (version 11076708, May 2024).
  static const Map<String, String> _downloadUrls = {
    "linux":
        "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip",
    "macos":
        "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip",
    "windows":
        "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip",
  };

  String get sdkRoot {
    // Honour explicit env vars first.
    final fromEnv = Platform.environment["ANDROID_HOME"] ??
        Platform.environment["ANDROID_SDK_ROOT"];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    // Fall back to the platform-specific standard location.
    final home = Platform.environment["HOME"] ??
        Platform.environment["USERPROFILE"] ??
        ".";
    if (Platform.isWindows) {
      // Check the common Windows locations.
      final localAppData = Platform.environment["LOCALAPPDATA"];
      if (localAppData != null) {
        final candidate = p.join(localAppData, "Android", "Sdk");
        if (Directory(candidate).existsSync()) return candidate;
      }
      return p.join(home, "Android", "android-sdk");
    } else if (Platform.isMacOS) {
      return p.join(home, "Library", "Android", "sdk");
    } else {
      return p.join(home, "Android", "Sdk");
    }
  }

  String get _downloadUrl {
    if (Platform.isLinux) return _downloadUrls["linux"]!;
    if (Platform.isMacOS) return _downloadUrls["macos"]!;
    if (Platform.isWindows) return _downloadUrls["windows"]!;
    throw const AvdException(
        "Unsupported platform for automatic SDK installation.");
  }

  // ---------------------------------------------------------------------------
  // Main installation entry-point
  // ---------------------------------------------------------------------------

  /// Downloads cmdline-tools, extracts them, accepts SDK licences, and
  /// installs `platform-tools` and `emulator`.
  ///
  /// Progress events are sent to [onProgress]:
  ///   - `message` is a human-readable description of the current step.
  ///   - `progress` is in `[0.0, 1.0]` or `-1` for indeterminate.
  Future<void> installSdk(
      void Function(String message, double progress) onProgress) async {
    final zipPath = p.join(sdkRoot, "cmdline-tools.zip");
    final cmdlineDir = p.join(sdkRoot, "cmdline-tools");

    // 1. Create the SDK root directory.
    onProgress("Creating SDK directory…", 0.0);
    Directory(sdkRoot).createSync(recursive: true);

    // 2. Download the zip.
    onProgress("Downloading Android command-line tools…", 0.05);
    await _download(_downloadUrl, zipPath, (received, total) {
      final pct = total > 0 ? (received / total) * 0.4 + 0.05 : -1.0;
      onProgress("Downloading… ${_fmt(received)} / ${_fmt(total)}", pct);
    });

    // 3. Unzip.
    onProgress("Extracting tools…", 0.45);
    await _unzip(zipPath, sdkRoot);
    File(zipPath).deleteSync();

    // 4. Move extracted "cmdline-tools" folder to the expected layout.
    //    The zip contains: cmdline-tools/bin, cmdline-tools/lib, ...
    //    sdkmanager requires:  <sdk>/cmdline-tools/latest/...
    final extracted = Directory(cmdlineDir);
    final latest = Directory(p.join(cmdlineDir, "latest"));
    if (extracted.existsSync() && !latest.existsSync()) {
      // Rename the folder to "latest".
      final tmp = Directory(p.join(sdkRoot, "_cmdline-tools-tmp"));
      await extracted.rename(tmp.path);
      Directory(cmdlineDir).createSync();
      await tmp.rename(latest.path);
    }

    // 5. Accept licences.
    onProgress("Accepting SDK licences…", 0.50);
    final sdkManager = _sdkManagerPath;
    await _runWithInput(sdkManager, ["--licenses"],
        input: "y\n" * 30, env: _env);

    // 6. Install emulator and platform-tools.
    onProgress("Installing emulator and platform-tools…", 0.55);
    await _runStreamed(
      sdkManager,
      ["platform-tools", "emulator"],
      env: _env,
      onLine: (l) => onProgress(l, -1),
    );

    onProgress("SDK installed successfully.", 1.0);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String get _sdkManagerPath {
    final ext = Platform.isWindows ? ".bat" : "";
    return p.join(sdkRoot, "cmdline-tools", "latest", "bin", "sdkmanager$ext");
  }

  Map<String, String> get _env {
    final env = Map<String, String>.from(Platform.environment);
    env["ANDROID_HOME"] = sdkRoot;
    env["ANDROID_SDK_ROOT"] = sdkRoot;
    return env;
  }

  Future<void> _download(
    String url,
    String destPath,
    void Function(int received, int total) onProgress,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw AvdException(
            "Failed to download SDK tools (HTTP ${response.statusCode}).\n"
            "URL: $url\n"
            "Please download manually from https://developer.android.com/studio#command-tools");
      }

      final total = response.contentLength;
      int received = 0;
      final file = File(destPath).openWrite();

      await for (final chunk in response) {
        file.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }

      await file.close();
    } finally {
      client.close();
    }
  }

  Future<void> _unzip(String zipPath, String destDir) async {
    if (Platform.isWindows) {
      // PowerShell is available on all modern Windows installations.
      final result = await Process.run("powershell", [
        "-NoProfile",
        "-Command",
        'Expand-Archive -Force -Path "$zipPath" -DestinationPath "$destDir"',
      ]);
      if (result.exitCode != 0) {
        throw AvdException("Extraction failed: ${result.stderr}");
      }
    } else {
      final result = await Process.run("unzip", ["-o", zipPath, "-d", destDir]);
      if (result.exitCode != 0) {
        throw AvdException("Extraction failed: ${result.stderr}");
      }
    }
  }

  Future<void> _runWithInput(
    String exe,
    List<String> args, {
    required String input,
    Map<String, String>? env,
  }) async {
    final process = await Process.start(exe, args, environment: env);

    // Drain stdout/stderr so the process never blocks on a full pipe buffer.
    await process.stdout.drain<void>();
    await process.stderr.drain<void>();

    process.stdin.write(input);
    await process.stdin.close();
    await process.exitCode; // wait for completion
  }

  Future<void> _runStreamed(
    String exe,
    List<String> args, {
    void Function(String line)? onLine,
    Map<String, String>? env,
  }) async {
    final process = await Process.start(exe, args, environment: env);
    await process.stdin.close();

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine ?? (_) {});
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine ?? (_) {});

    final code = await process.exitCode;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (code != 0) {
      throw AvdException('Command "$exe" failed with exit code $code.');
    }
  }

  static String _fmt(int bytes) {
    if (bytes < 0) return "?";
    if (bytes < 1024) return "${bytes}B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)}KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB";
  }
}

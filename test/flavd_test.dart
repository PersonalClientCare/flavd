import "package:flutter_test/flutter_test.dart";

import "package:flavd/models/avd_device.dart";
import "package:flavd/models/form_factor.dart";
import "package:flavd/models/api_level.dart";
import "package:flavd/services/avd_service.dart";

void main() {
  // ---------------------------------------------------------------------------
  // AvdDevice model
  // ---------------------------------------------------------------------------
  group("AvdDevice", () {
    test("copyWith overrides only specified fields", () {
      const original = AvdDevice(
        name: "Pixel_6",
        tagAbi: "google_apis/x86_64",
      );
      final copy = original.copyWith(isRunning: true);
      expect(copy.name, "Pixel_6");
      expect(copy.tagAbi, "google_apis/x86_64");
      expect(copy.isRunning, true);
      expect(original.isRunning, false);
    });

    test("default isRunning is false", () {
      const d = AvdDevice(name: "Test");
      expect(d.isRunning, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // FormFactor
  // ---------------------------------------------------------------------------
  group("FormFactor", () {
    test("preset list is non-empty and contains expected entries", () {
      expect(FormFactor.presets, isNotEmpty);
      expect(FormFactor.presets.map((f) => f.name), contains("Phone"));
      expect(FormFactor.presets.map((f) => f.name), contains("Small Phone"));
      expect(FormFactor.presets.map((f) => f.name), contains("Tablet"));
      expect(FormFactor.presets.map((f) => f.name), contains("Small Tablet"));
      expect(FormFactor.presets.map((f) => f.name), contains("Custom"));
    });

    test("custom preset has isCustom = true", () {
      expect(FormFactor.custom.isCustom, isTrue);
    });

    test("non-custom presets have isCustom = false", () {
      for (final f in FormFactor.presets.where((f) => !f.isCustom)) {
        expect(f.isCustom, isFalse, reason: "${f.name} should not be custom");
      }
    });

    test("toString returns name", () {
      expect(FormFactor.phone.toString(), "Phone");
    });

    test("diagonalInches is positive for normal presets", () {
      for (final f in FormFactor.presets.where((f) => !f.isCustom)) {
        expect(
          f.diagonalInches,
          greaterThan(0),
          reason: "${f.name} should have positive diagonal",
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ApiLevel
  // ---------------------------------------------------------------------------
  group("ApiLevel", () {
    test("supported list is non-empty", () {
      expect(ApiLevel.supported, isNotEmpty);
    });

    test("first entry is the highest API level", () {
      expect(
        ApiLevel.supported.first.level,
        greaterThanOrEqualTo(ApiLevel.supported.last.level),
      );
    });

    test("packageId produces correct format", () {
      const api = ApiLevel(level: 34, name: "Android 14");
      expect(
        api.packageId(),
        "system-images;android-34;google_apis;x86_64",
      );
    });

    test("packageId respects custom tag and abi", () {
      const api = ApiLevel(level: 33, name: "Android 13");
      expect(
        api.packageId(tag: "default", abi: "arm64-v8a"),
        "system-images;android-33;default;arm64-v8a",
      );
    });

    test("toString includes API level number and name", () {
      const api = ApiLevel(level: 34, name: "Android 14");
      expect(api.toString(), contains("34"));
      expect(api.toString(), contains("Android 14"));
    });
  });

  // ---------------------------------------------------------------------------
  // AvdService – output parsing
  // ---------------------------------------------------------------------------
  group("AvdService output parsing", () {
    late AvdService svc;

    setUp(() => svc = AvdService());

    test("parses single device block", () {
      const output = """
Available Android Virtual Devices:
    Name: Pixel_6_API_34
  Device: pixel_6 (Google)
    Path: /home/user/.android/avd/Pixel_6_API_34.avd
  Target: Google APIs (Google Inc.)
         Based on: Android 14.0 (UpsideDownCake) Tag/ABI: google_apis/x86_64
   Sdcard: 512 MB
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "Pixel_6_API_34");
      expect(devices.first.tagAbi, "google_apis/x86_64");
    });

    test("parses multiple device blocks separated by dashes", () {
      const output = """
Available Android Virtual Devices:
    Name: DeviceA
    Path: /path/a.avd
---------
    Name: DeviceB
    Path: /path/b.avd
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 2);
      expect(devices.map((d) => d.name), containsAll(["DeviceA", "DeviceB"]));
    });

    test("returns empty list when no devices", () {
      const output = "Available Android Virtual Devices:\n";
      expect(svc.parseAvdListOutput(output), isEmpty);
    });

    test("handles missing optional fields gracefully", () {
      const output = """
    Name: Minimal
    Path: /path/minimal.avd
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.tagAbi, isNull);
      expect(devices.first.basedOn, isNull);
    });
  });
}

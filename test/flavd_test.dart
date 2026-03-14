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

    test("copyWith can override every field", () {
      const original = AvdDevice(name: "Original");
      final copy = original.copyWith(
        name: "Changed",
        device: "pixel_7",
        path: "/new/path",
        target: "Google APIs",
        basedOn: "Android 14",
        tagAbi: "default/arm64-v8a",
        sdcard: "256 MB",
        isRunning: true,
      );
      expect(copy.name, "Changed");
      expect(copy.device, "pixel_7");
      expect(copy.path, "/new/path");
      expect(copy.target, "Google APIs");
      expect(copy.basedOn, "Android 14");
      expect(copy.tagAbi, "default/arm64-v8a");
      expect(copy.sdcard, "256 MB");
      expect(copy.isRunning, isTrue);
    });

    test("copyWith with no arguments returns identical values", () {
      const original = AvdDevice(
        name: "NoChange",
        device: "pixel_6",
        path: "/some/path",
        target: "target",
        basedOn: "Android 13",
        tagAbi: "google_apis/x86_64",
        sdcard: "512 MB",
        isRunning: true,
      );
      final copy = original.copyWith();
      expect(copy.name, original.name);
      expect(copy.device, original.device);
      expect(copy.path, original.path);
      expect(copy.target, original.target);
      expect(copy.basedOn, original.basedOn);
      expect(copy.tagAbi, original.tagAbi);
      expect(copy.sdcard, original.sdcard);
      expect(copy.isRunning, original.isRunning);
    });

    test("all optional fields default to null", () {
      const d = AvdDevice(name: "Minimal");
      expect(d.device, isNull);
      expect(d.path, isNull);
      expect(d.target, isNull);
      expect(d.basedOn, isNull);
      expect(d.tagAbi, isNull);
      expect(d.sdcard, isNull);
    });

    test("toString contains name and running state", () {
      const d = AvdDevice(name: "MyDevice", isRunning: true);
      final s = d.toString();
      expect(s, contains("MyDevice"));
      expect(s, contains("true"));
    });

    test("toString for non-running device contains false", () {
      const d = AvdDevice(name: "Stopped");
      expect(d.toString(), contains("false"));
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

    test("diagonalInches returns 0 when density is 0", () {
      const f = FormFactor(name: "Zero", width: 100, height: 200, density: 0);
      expect(f.diagonalInches, 0);
    });

    test("preset count matches expected number", () {
      // phone, smallPhone, tablet, smallTablet, foldable, tv, wear, custom
      expect(FormFactor.presets.length, 8);
    });

    test("all presets have non-empty names", () {
      for (final f in FormFactor.presets) {
        expect(f.name.isNotEmpty, isTrue,
            reason: "Preset name must not be empty");
      }
    });

    test("all non-custom presets have positive dimensions and density", () {
      for (final f in FormFactor.presets.where((f) => !f.isCustom)) {
        expect(f.width, greaterThan(0), reason: "${f.name} width");
        expect(f.height, greaterThan(0), reason: "${f.name} height");
        expect(f.density, greaterThan(0), reason: "${f.name} density");
      }
    });

    test("phone diagonal is roughly correct", () {
      // 1080x2400 @ 420dpi ≈ 6.3"
      final d = FormFactor.phone.diagonalInches;
      expect(d, greaterThan(5.5));
      expect(d, lessThan(7.5));
    });

    test("tablet diagonal is larger than phone", () {
      expect(
        FormFactor.tablet.diagonalInches,
        greaterThan(FormFactor.phone.diagonalInches),
      );
    });

    test("wear diagonal is the smallest non-custom preset", () {
      final wearDiag = FormFactor.wear.diagonalInches;
      for (final f in FormFactor.presets
          .where((f) => !f.isCustom && f != FormFactor.wear)) {
        expect(
          wearDiag,
          lessThan(f.diagonalInches),
          reason: "Wear OS should be smaller than ${f.name}",
        );
      }
    });

    test("foldable preset has expected dimensions", () {
      expect(FormFactor.foldable.width, 1768);
      expect(FormFactor.foldable.height, 2208);
      expect(FormFactor.foldable.density, 420);
    });

    test("tv preset has landscape orientation (width > height)", () {
      expect(FormFactor.tv.width, greaterThan(FormFactor.tv.height));
    });

    test("wear preset has square dimensions", () {
      expect(FormFactor.wear.width, FormFactor.wear.height);
    });

    test("custom preset has default dimensions", () {
      expect(FormFactor.custom.width, greaterThan(0));
      expect(FormFactor.custom.height, greaterThan(0));
      expect(FormFactor.custom.density, greaterThan(0));
    });

    test("preset names are all unique", () {
      final names = FormFactor.presets.map((f) => f.name).toList();
      expect(names.toSet().length, names.length);
    });

    test("exactly one preset is custom", () {
      final customCount = FormFactor.presets.where((f) => f.isCustom).length;
      expect(customCount, 1);
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

    test("supported list is sorted descending by level", () {
      for (int i = 0; i < ApiLevel.supported.length - 1; i++) {
        expect(
          ApiLevel.supported[i].level,
          greaterThan(ApiLevel.supported[i + 1].level),
          reason:
              "Index $i (API ${ApiLevel.supported[i].level}) should be > index ${i + 1} (API ${ApiLevel.supported[i + 1].level})",
        );
      }
    });

    test("all supported levels have unique level numbers", () {
      final levels = ApiLevel.supported.map((a) => a.level).toList();
      expect(levels.toSet().length, levels.length);
    });

    test("all supported levels have non-empty names", () {
      for (final api in ApiLevel.supported) {
        expect(api.name.isNotEmpty, isTrue,
            reason: "API ${api.level} name must not be empty");
      }
    });

    test("supported range covers API 26 through 35", () {
      final levels = ApiLevel.supported.map((a) => a.level).toSet();
      expect(levels, contains(26));
      expect(levels, contains(35));
    });

    test("packageId with google_apis_playstore tag", () {
      const api = ApiLevel(level: 35, name: "Android 15");
      expect(
        api.packageId(tag: "google_apis_playstore"),
        "system-images;android-35;google_apis_playstore;x86_64",
      );
    });

    test("all names contain Android", () {
      for (final api in ApiLevel.supported) {
        expect(
          api.name,
          contains("Android"),
          reason: "API ${api.level} name should contain 'Android'",
        );
      }
    });

    test("supported list has exactly 10 entries", () {
      // API 26 through 35
      expect(ApiLevel.supported.length, 10);
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

    test("parses all fields from a complete device block", () {
      const output = """
    Name: FullDevice
  Device: pixel_7 (Google)
    Path: /home/user/.android/avd/FullDevice.avd
  Target: Google APIs (Google Inc.)
         Based on: Android 13.0 (Tiramisu) Tag/ABI: google_apis/x86_64
   Sdcard: 1024 MB
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      final d = devices.first;
      expect(d.name, "FullDevice");
      expect(d.device, "pixel_7 (Google)");
      expect(d.path, "/home/user/.android/avd/FullDevice.avd");
      expect(d.target, "Google APIs (Google Inc.)");
      expect(d.tagAbi, "google_apis/x86_64");
      expect(d.sdcard, "1024 MB");
    });

    test("parses three device blocks", () {
      const output = """
Available Android Virtual Devices:
    Name: Alpha
    Path: /path/alpha.avd
---------
    Name: Beta
    Path: /path/beta.avd
---------
    Name: Gamma
    Path: /path/gamma.avd
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 3);
      expect(devices[0].name, "Alpha");
      expect(devices[1].name, "Beta");
      expect(devices[2].name, "Gamma");
    });

    test("handles empty string input", () {
      expect(svc.parseAvdListOutput(""), isEmpty);
    });

    test("handles output with only dashes and no device blocks", () {
      const output = "----------\n----------\n";
      expect(svc.parseAvdListOutput(output), isEmpty);
    });

    test("trims whitespace in field values", () {
      const output = """
    Name:    SpacedName
    Path:   /some/path
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "SpacedName");
      expect(devices.first.path, "/some/path");
    });

    test("handles Based on with Tag/ABI on same line", () {
      const output = """
    Name: TestDevice
         Based on: Android 12.0 (Snow Cone) Tag/ABI: default/x86_64
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.basedOn, isNotNull);
      expect(devices.first.tagAbi, "default/x86_64");
    });

    test("parses device with Windows-style path", () {
      const output = r"""
    Name: WinDevice
    Path: C:\Users\user\.android\avd\WinDevice.avd
  Target: Google APIs (Google Inc.)
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "WinDevice");
      expect(devices.first.path, contains("WinDevice.avd"));
      expect(devices.first.target, "Google APIs (Google Inc.)");
    });

    test("ignores blocks without a Name field", () {
      const output = """
Some random header text
  Device: pixel_6 (Google)
    Path: /path/orphan.avd
---------
    Name: RealDevice
    Path: /path/real.avd
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "RealDevice");
    });

    test("parses device name with dots and hyphens", () {
      const output = """
    Name: My.Device-2024_v1
    Path: /path/test.avd
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "My.Device-2024_v1");
    });

    test("parses device with only Name field", () {
      const output = """
    Name: OnlyName
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 1);
      expect(devices.first.name, "OnlyName");
      expect(devices.first.device, isNull);
      expect(devices.first.path, isNull);
      expect(devices.first.target, isNull);
      expect(devices.first.basedOn, isNull);
      expect(devices.first.tagAbi, isNull);
      expect(devices.first.sdcard, isNull);
      expect(devices.first.isRunning, isFalse);
    });

    test("parses realistic avdmanager output", () {
      const output = """
Available Android Virtual Devices:
    Name: Pixel_6_API_34
  Device: pixel_6 (Google)
    Path: /home/dev/.android/avd/Pixel_6_API_34.avd
  Target: Google APIs (Google Inc.)
         Based on: Android 14.0 (UpsideDownCake) Tag/ABI: google_apis/x86_64
   Sdcard: 512 MB
---------
    Name: Tablet_API_33
  Device: pixel_c (Google)
    Path: /home/dev/.android/avd/Tablet_API_33.avd
  Target: Google Play (Google Inc.)
         Based on: Android 13.0 (Tiramisu) Tag/ABI: google_apis_playstore/x86_64
   Sdcard: 512 MB
---------
    Name: WearOS_Round
    Path: /home/dev/.android/avd/WearOS_Round.avd
  Target: Android Wear (Google Inc.)
         Based on: Android 11.0 (Red Velvet Cake) Tag/ABI: android-wear/x86
""";
      final devices = svc.parseAvdListOutput(output);
      expect(devices.length, 3);

      expect(devices[0].name, "Pixel_6_API_34");
      expect(devices[0].device, "pixel_6 (Google)");
      expect(devices[0].tagAbi, "google_apis/x86_64");

      expect(devices[1].name, "Tablet_API_33");
      expect(devices[1].tagAbi, "google_apis_playstore/x86_64");

      expect(devices[2].name, "WearOS_Round");
      expect(devices[2].device, isNull);
      expect(devices[2].tagAbi, "android-wear/x86");
    });
  });
}

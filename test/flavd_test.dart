import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:qr/qr.dart";

import "package:flavd/models/adb_device.dart";
import "package:flavd/models/avd_device.dart";
import "package:flavd/models/form_factor.dart";
import "package:flavd/models/api_level.dart";
import "package:flavd/services/avd_service.dart";
import "package:flavd/widgets/qr_painter_widget.dart";

void main() {
  // ---------------------------------------------------------------------------
  // AvdDevice model
  // ---------------------------------------------------------------------------
  group("AvdDevice", () {
    test("copyWith overrides only specified fields", () {
      const original = AvdDevice(name: "Pixel_6", tagAbi: "google_apis/x86_64");
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
        expect(
          f.name.isNotEmpty,
          isTrue,
          reason: "Preset name must not be empty",
        );
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
      for (final f in FormFactor.presets.where(
        (f) => !f.isCustom && f != FormFactor.wear,
      )) {
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
      expect(api.packageId(), "system-images;android-34;google_apis;x86_64");
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
        expect(
          api.name.isNotEmpty,
          isTrue,
          reason: "API ${api.level} name must not be empty",
        );
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

  // ---------------------------------------------------------------------------
  // AdbDevice model
  // ---------------------------------------------------------------------------
  group("AdbDevice", () {
    test("isWireless returns true for IP:port serials", () {
      const d = AdbDevice(serial: "192.168.1.42:5555");
      expect(d.isWireless, isTrue);
    });

    test("isWireless returns false for USB serials", () {
      const d = AdbDevice(serial: "RZCW30ABCDEF");
      expect(d.isWireless, isFalse);
    });

    test("isWireless returns false for emulator-like serials", () {
      const d = AdbDevice(serial: "emulator-5554");
      expect(d.isWireless, isFalse);
    });

    test("isWireless returns true for various IP addresses", () {
      const d1 = AdbDevice(serial: "10.0.0.1:37123");
      const d2 = AdbDevice(serial: "172.16.255.1:5555");
      const d3 = AdbDevice(serial: "255.255.255.255:65535");
      expect(d1.isWireless, isTrue);
      expect(d2.isWireless, isTrue);
      expect(d3.isWireless, isTrue);
    });

    test("isWireless returns false for partial IP without port", () {
      const d = AdbDevice(serial: "192.168.1.42");
      expect(d.isWireless, isFalse);
    });

    test("displayName returns model when available", () {
      const d = AdbDevice(serial: "192.168.1.42:5555", model: "Pixel_6");
      expect(d.displayName, "Pixel_6");
    });

    test("displayName returns serial when model is null", () {
      const d = AdbDevice(serial: "192.168.1.42:5555");
      expect(d.displayName, "192.168.1.42:5555");
    });

    test("displayName returns serial when model is empty", () {
      const d = AdbDevice(serial: "RZCW30ABCDEF", model: "");
      expect(d.displayName, "RZCW30ABCDEF");
    });

    test("default state is device", () {
      const d = AdbDevice(serial: "test");
      expect(d.state, AdbDeviceState.device);
    });

    test("copyWith overrides only specified fields", () {
      const original = AdbDevice(
        serial: "192.168.1.42:5555",
        model: "Pixel_6",
        product: "oriole",
        transportId: "3",
        state: AdbDeviceState.device,
      );
      final copy = original.copyWith(state: AdbDeviceState.offline);
      expect(copy.serial, "192.168.1.42:5555");
      expect(copy.model, "Pixel_6");
      expect(copy.product, "oriole");
      expect(copy.transportId, "3");
      expect(copy.state, AdbDeviceState.offline);
    });

    test("copyWith with no arguments returns identical values", () {
      const original = AdbDevice(
        serial: "RZCW30ABCDEF",
        model: "Galaxy_S22",
        product: "dm1q",
        transportId: "1",
        state: AdbDeviceState.unauthorized,
      );
      final copy = original.copyWith();
      expect(copy.serial, original.serial);
      expect(copy.model, original.model);
      expect(copy.product, original.product);
      expect(copy.transportId, original.transportId);
      expect(copy.state, original.state);
    });

    test("copyWith can override every field", () {
      const original = AdbDevice(serial: "old");
      final copy = original.copyWith(
        serial: "new_serial",
        model: "new_model",
        product: "new_product",
        transportId: "99",
        state: AdbDeviceState.recovery,
      );
      expect(copy.serial, "new_serial");
      expect(copy.model, "new_model");
      expect(copy.product, "new_product");
      expect(copy.transportId, "99");
      expect(copy.state, AdbDeviceState.recovery);
    });

    test("all optional fields default to null", () {
      const d = AdbDevice(serial: "test");
      expect(d.model, isNull);
      expect(d.product, isNull);
      expect(d.transportId, isNull);
    });

    test("toString contains serial and model", () {
      const d = AdbDevice(serial: "192.168.1.42:5555", model: "Pixel_6");
      final s = d.toString();
      expect(s, contains("192.168.1.42:5555"));
      expect(s, contains("Pixel_6"));
    });

    test("toString contains state", () {
      const d = AdbDevice(serial: "test", state: AdbDeviceState.unauthorized);
      expect(d.toString(), contains("unauthorized"));
    });
  });

  // ---------------------------------------------------------------------------
  // AdbDeviceState
  // ---------------------------------------------------------------------------
  group("AdbDeviceState", () {
    test("fromString parses 'device'", () {
      expect(AdbDeviceState.fromString("device"), AdbDeviceState.device);
    });

    test("fromString parses 'offline'", () {
      expect(AdbDeviceState.fromString("offline"), AdbDeviceState.offline);
    });

    test("fromString parses 'unauthorized'", () {
      expect(
        AdbDeviceState.fromString("unauthorized"),
        AdbDeviceState.unauthorized,
      );
    });

    test("fromString parses 'recovery'", () {
      expect(AdbDeviceState.fromString("recovery"), AdbDeviceState.recovery);
    });

    test("fromString returns unknown for unrecognised strings", () {
      expect(AdbDeviceState.fromString("bogus"), AdbDeviceState.unknown);
      expect(AdbDeviceState.fromString(""), AdbDeviceState.unknown);
    });

    test("fromString is case-insensitive", () {
      expect(AdbDeviceState.fromString("DEVICE"), AdbDeviceState.device);
      expect(AdbDeviceState.fromString("Device"), AdbDeviceState.device);
      expect(AdbDeviceState.fromString("OFFLINE"), AdbDeviceState.offline);
      expect(
        AdbDeviceState.fromString("Unauthorized"),
        AdbDeviceState.unauthorized,
      );
    });

    test("fromString trims whitespace", () {
      expect(AdbDeviceState.fromString("  device  "), AdbDeviceState.device);
      expect(AdbDeviceState.fromString("\toffline\n"), AdbDeviceState.offline);
    });

    test("label returns human-readable text for each state", () {
      expect(AdbDeviceState.device.label, "Online");
      expect(AdbDeviceState.recovery.label, "Recovery");
      expect(AdbDeviceState.unauthorized.label, "Unauthorized");
      expect(AdbDeviceState.offline.label, "Offline");
      expect(AdbDeviceState.unknown.label, "Unknown");
    });

    test("all enum values have non-empty labels", () {
      for (final state in AdbDeviceState.values) {
        expect(
          state.label.isNotEmpty,
          isTrue,
          reason: "$state should have a non-empty label",
        );
      }
    });

    test("enum has exactly 5 values", () {
      expect(AdbDeviceState.values.length, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // AvdService – ADB devices output parsing
  // ---------------------------------------------------------------------------
  group("AvdService ADB devices parsing", () {
    late AvdService svc;

    setUp(() => svc = AvdService());

    test("parses single wireless device", () {
      const output = """
List of devices attached
192.168.1.42:5555      device product:oriole model:Pixel_6 transport_id:3
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "192.168.1.42:5555");
      expect(devices.first.model, "Pixel_6");
      expect(devices.first.product, "oriole");
      expect(devices.first.transportId, "3");
      expect(devices.first.state, AdbDeviceState.device);
      expect(devices.first.isWireless, isTrue);
    });

    test("parses single USB device", () {
      const output = """
List of devices attached
RZCW30ABCDEF           device product:dm1q model:Galaxy_S22 transport_id:1
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "RZCW30ABCDEF");
      expect(devices.first.model, "Galaxy_S22");
      expect(devices.first.product, "dm1q");
      expect(devices.first.transportId, "1");
      expect(devices.first.state, AdbDeviceState.device);
      expect(devices.first.isWireless, isFalse);
    });

    test("skips emulator devices", () {
      const output = """
List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 transport_id:1
192.168.1.42:5555      device product:oriole model:Pixel_6 transport_id:3
emulator-5556          device product:sdk_gphone model:sdk_gphone transport_id:2
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "192.168.1.42:5555");
    });

    test("parses multiple physical devices", () {
      const output = """
List of devices attached
RZCW30ABCDEF           device product:dm1q model:Galaxy_S22 transport_id:1
192.168.1.42:5555      device product:oriole model:Pixel_6 transport_id:3
ABC123XYZ              device product:raven model:Pixel_6_Pro transport_id:5
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 3);
      expect(devices[0].serial, "RZCW30ABCDEF");
      expect(devices[1].serial, "192.168.1.42:5555");
      expect(devices[2].serial, "ABC123XYZ");
    });

    test("parses unauthorized device", () {
      const output = """
List of devices attached
RZCW30ABCDEF           unauthorized transport_id:1
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "RZCW30ABCDEF");
      expect(devices.first.state, AdbDeviceState.unauthorized);
      expect(devices.first.model, isNull);
    });

    test("parses offline device", () {
      const output = """
List of devices attached
192.168.1.42:5555      offline
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "192.168.1.42:5555");
      expect(devices.first.state, AdbDeviceState.offline);
      expect(devices.first.isWireless, isTrue);
    });

    test("parses mixed states", () {
      const output = """
List of devices attached
AAAA1111               device product:oriole model:Pixel_6 transport_id:1
BBBB2222               unauthorized transport_id:2
192.168.1.10:5555      offline
CCCC3333               device product:raven model:Pixel_6_Pro transport_id:4
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 4);
      expect(devices[0].state, AdbDeviceState.device);
      expect(devices[1].state, AdbDeviceState.unauthorized);
      expect(devices[2].state, AdbDeviceState.offline);
      expect(devices[3].state, AdbDeviceState.device);
    });

    test("returns empty list for no devices", () {
      const output = """
List of devices attached

""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices, isEmpty);
    });

    test("returns empty list for empty string", () {
      expect(svc.parseAdbDevicesOutput(""), isEmpty);
    });

    test("returns empty list when only emulators are present", () {
      const output = """
List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 transport_id:1
emulator-5556          device product:sdk_gphone model:sdk_gphone transport_id:2
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices, isEmpty);
    });

    test("handles device with no extra properties", () {
      const output = """
List of devices attached
RZCW30ABCDEF           device
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "RZCW30ABCDEF");
      expect(devices.first.state, AdbDeviceState.device);
      expect(devices.first.model, isNull);
      expect(devices.first.product, isNull);
      expect(devices.first.transportId, isNull);
    });

    test("handles device with only some properties", () {
      const output = """
List of devices attached
RZCW30ABCDEF           device model:Pixel_6
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.model, "Pixel_6");
      expect(devices.first.product, isNull);
      expect(devices.first.transportId, isNull);
    });

    test("handles recovery state", () {
      const output = """
List of devices attached
RZCW30ABCDEF           recovery
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.state, AdbDeviceState.recovery);
    });

    test("parses wireless device with high port number", () {
      const output = """
List of devices attached
10.0.0.123:43567       device product:panther model:Pixel_7 transport_id:8
""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 1);
      expect(devices.first.serial, "10.0.0.123:43567");
      expect(devices.first.model, "Pixel_7");
      expect(devices.first.isWireless, isTrue);
    });

    test("ignores header line", () {
      const output = "List of devices attached\n";
      expect(svc.parseAdbDevicesOutput(output), isEmpty);
    });

    test("ignores blank lines mixed in output", () {
      const output = """
List of devices attached

AAAA1111               device product:oriole model:Pixel_6 transport_id:1

BBBB2222               device product:raven model:Pixel_6_Pro transport_id:2

""";
      final devices = svc.parseAdbDevicesOutput(output);
      expect(devices.length, 2);
    });

    test(
      "handles realistic mixed output with emulators and physical devices",
      () {
        const output = """
List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 transport_id:1
RZCW30ABCDEF           device product:dm1q model:SM_S901B transport_id:2
192.168.1.100:37845    device product:oriole model:Pixel_6 transport_id:3
emulator-5556          device product:sdk_gphone model:sdk_gphone transport_id:4
10.0.0.5:5555          unauthorized transport_id:5
""";
        final devices = svc.parseAdbDevicesOutput(output);
        expect(devices.length, 3);

        expect(devices[0].serial, "RZCW30ABCDEF");
        expect(devices[0].model, "SM_S901B");
        expect(devices[0].isWireless, isFalse);
        expect(devices[0].state, AdbDeviceState.device);

        expect(devices[1].serial, "192.168.1.100:37845");
        expect(devices[1].model, "Pixel_6");
        expect(devices[1].isWireless, isTrue);
        expect(devices[1].state, AdbDeviceState.device);

        expect(devices[2].serial, "10.0.0.5:5555");
        expect(devices[2].isWireless, isTrue);
        expect(devices[2].state, AdbDeviceState.unauthorized);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // QR pairing payload format
  // ---------------------------------------------------------------------------
  group("QR pairing payload format", () {
    /// Builds the same payload string that [_WirelessAdbScreenState] builds.
    String buildQrPayload({
      required String password,
      String serviceName = "adb-flavd-pair",
    }) {
      return "WIFI:T:ADB;S:$serviceName;P:$password;;";
    }

    test("payload has correct format with default service name", () {
      final payload = buildQrPayload(password: "482924");
      expect(payload, "WIFI:T:ADB;S:adb-flavd-pair;P:482924;;");
    });

    test("payload has correct format with custom service name", () {
      final payload = buildQrPayload(
        password: "123456",
        serviceName: "my-device",
      );
      expect(payload, "WIFI:T:ADB;S:my-device;P:123456;;");
    });

    test("payload starts with WIFI:T:ADB", () {
      final payload = buildQrPayload(password: "000000");
      expect(payload, startsWith("WIFI:T:ADB;"));
    });

    test("payload ends with double semicolons", () {
      final payload = buildQrPayload(password: "999999");
      expect(payload, endsWith(";;"));
    });

    test("payload contains S: (service name) field", () {
      final payload = buildQrPayload(
        password: "111111",
        serviceName: "test-svc",
      );
      expect(payload, contains("S:test-svc;"));
    });

    test("payload contains P: (password) field", () {
      final payload = buildQrPayload(password: "654321");
      expect(payload, contains("P:654321;"));
    });

    test("payload with empty service name falls back to provided value", () {
      // The screen defaults to "adb-flavd-pair" when empty, but the builder
      // itself just uses whatever is passed.
      final payload = buildQrPayload(password: "123456", serviceName: "");
      expect(payload, "WIFI:T:ADB;S:;P:123456;;");
    });

    test("payload with long password is valid", () {
      final payload = buildQrPayload(password: "abcdef123456789");
      expect(payload, "WIFI:T:ADB;S:adb-flavd-pair;P:abcdef123456789;;");
    });

    test("payload can be encoded as a QR code without error", () {
      final payload = buildQrPayload(password: "482924");
      expect(
        () => QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
        returnsNormally,
      );
    });

    test("QR code from payload produces valid image", () {
      final payload = buildQrPayload(password: "482924");
      final qrCode = QrCode.fromData(
        data: payload,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      expect(qrImage.moduleCount, greaterThan(0));
    });

    test("QR code module count is consistent for same data", () {
      final payload = buildQrPayload(password: "482924");
      final qr1 = QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
      final qr2 = QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
      expect(qr1.moduleCount, qr2.moduleCount);
    });

    test("QR image isDark returns bool for all valid coordinates", () {
      final payload = buildQrPayload(password: "482924");
      final qrCode = QrCode.fromData(
        data: payload,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      for (var row = 0; row < qrImage.moduleCount; row++) {
        for (var col = 0; col < qrImage.moduleCount; col++) {
          // Should not throw, and should return a bool.
          expect(qrImage.isDark(row, col), isA<bool>());
        }
      }
    });

    test("different passwords produce different QR images", () {
      final img1 = QrImage(
        QrCode.fromData(
          data: buildQrPayload(password: "111111"),
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
      final img2 = QrImage(
        QrCode.fromData(
          data: buildQrPayload(password: "222222"),
          errorCorrectLevel: QrErrorCorrectLevel.M,
        ),
      );
      // At least one module must differ between the two images.
      var hasDifference = false;
      final count = img1.moduleCount < img2.moduleCount
          ? img1.moduleCount
          : img2.moduleCount;
      for (var r = 0; r < count && !hasDifference; r++) {
        for (var c = 0; c < count && !hasDifference; c++) {
          if (img1.isDark(r, c) != img2.isDark(r, c)) {
            hasDifference = true;
          }
        }
      }
      if (!hasDifference) {
        // Different module counts also count as different.
        hasDifference = img1.moduleCount != img2.moduleCount;
      }
      expect(hasDifference, isTrue);
    });

    test("higher error correction level is accepted", () {
      final payload = buildQrPayload(password: "482924");
      expect(
        () => QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.H,
        ),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // QrPainterWidget
  // ---------------------------------------------------------------------------
  group("QrPainterWidget", () {
    testWidgets("renders without error", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrPainterWidget(data: "test-data")),
        ),
      );
      expect(find.byType(QrPainterWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QrPainterWidget),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets("respects custom size", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrPainterWidget(data: "test-data", size: 300)),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final constraints = container.constraints;
      expect(constraints?.maxWidth, 300);
      expect(constraints?.maxHeight, 300);
    });

    testWidgets("renders with ADB pairing payload", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrPainterWidget(
              data: "WIFI:T:ADB;S:adb-flavd-pair;P:482924;;",
            ),
          ),
        ),
      );
      expect(find.byType(QrPainterWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("applies custom colors", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrPainterWidget(
              data: "color-test",
              moduleColor: Colors.blue,
              backgroundColor: Colors.yellow,
            ),
          ),
        ),
      );
      // Widget renders without error — colors are passed to the painter.
      expect(find.byType(QrPainterWidget), findsOneWidget);
    });

    testWidgets("applies border radius via ClipRRect", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrPainterWidget(data: "clip-test", borderRadius: 20.0),
          ),
        ),
      );
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      final borderRadius = clipRRect.borderRadius as BorderRadius;
      expect(borderRadius, BorderRadius.circular(20.0));
    });

    testWidgets("default size is 200", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QrPainterWidget(data: "default-size")),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final constraints = container.constraints;
      expect(constraints?.maxWidth, 200);
      expect(constraints?.maxHeight, 200);
    });

    testWidgets("handles long data strings", (tester) async {
      final longData = "WIFI:T:ADB;S:${"x" * 100};P:${"9" * 50};;";
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: QrPainterWidget(data: longData)),
        ),
      );
      expect(find.byType(QrPainterWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("renders with all error correction levels", (tester) async {
      for (final level in [
        QrErrorCorrectLevel.L,
        QrErrorCorrectLevel.M,
        QrErrorCorrectLevel.Q,
        QrErrorCorrectLevel.H,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QrPainterWidget(data: "ecl-test", errorCorrectLevel: level),
            ),
          ),
        );
        expect(find.byType(QrPainterWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}

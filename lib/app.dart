import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "providers/device_provider.dart";
import "screens/home_screen.dart";
import "services/avd_service.dart";
import "services/sdk_installer_service.dart";

class FlavdApp extends StatelessWidget {
  const FlavdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "flavd",
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(.light),
      darkTheme: _buildTheme(.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = brightness == .light
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B6AC9),
            secondary: const Color(0xFF3DDC84),
            brightness: .light,
          )
        : ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B6AC9),
            primary: const Color(0xFF3DDC84),
            brightness: .dark,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: base.surfaceContainer,
        foregroundColor: base.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }
}

/// Creates the top-level [DeviceProvider] with its dependencies wired in.
ChangeNotifierProvider<DeviceProvider> buildProviders(Widget child) {
  final avdService = AvdService();
  final sdkInstaller = SdkInstallerService();

  return ChangeNotifierProvider<DeviceProvider>(
    create: (_) =>
        DeviceProvider(avdService: avdService, sdkInstaller: sdkInstaller),
    child: child,
  );
}

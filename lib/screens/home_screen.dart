import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "package:flavd/models/adb_device.dart";
import "package:flavd/models/avd_device.dart";
import "package:flavd/providers/device_provider.dart";
import "package:flavd/widgets/adb_device_card.dart";
import "package:flavd/widgets/device_card.dart";
import "package:flavd/screens/create_device_screen.dart";
import "package:flavd/screens/wireless_adb_screen.dart";

/// Main screen: shows the list of AVDs, physical ADB devices, and
/// SDK-not-found banner when needed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialise on first frame so the context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Wireless ADB button.
          Consumer<DeviceProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.wifi_tethering),
              tooltip: "Wireless ADB",
              onPressed: provider.sdkReady
                  ? () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const WirelessAdbScreen(),
                      ),
                    )
                  : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: () => context.read<DeviceProvider>().refresh(),
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // ----- Error banner -----
              if (provider.error != null)
                _ErrorBanner(
                  message: provider.error!,
                  onDismiss: provider.clearError,
                ),

              // ----- SDK not found -----
              if (provider.sdkChecked && !provider.sdkReady)
                _SdkNotFoundBanner(provider: provider),

              // ----- Install progress -----
              if (provider.installing)
                _InstallProgressBanner(
                  message: provider.installMessage,
                  progress: provider.installProgress,
                ),

              // ----- Device list -----
              Expanded(
                child: provider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : (provider.devices.isEmpty && provider.adbDevices.isEmpty)
                    ? _EmptyState(sdkReady: provider.sdkReady)
                    : _CombinedDeviceList(
                        avdDevices: provider.devices,
                        adbDevices: provider.adbDevices,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DeviceProvider>(
        builder: (context, provider, _) => FloatingActionButton.extended(
          onPressed: provider.sdkReady
              ? () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const CreateDeviceScreen()),
                )
              : null,
          icon: const Icon(Icons.add),
          label: const Text("New Device"),
          tooltip: provider.sdkReady
              ? "Create a new Android Virtual Device"
              : "Install SDK first",
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Displays both virtual (AVD) and physical (ADB) devices in a single
/// scrollable list, separated by section headers when both are present.
class _CombinedDeviceList extends StatelessWidget {
  const _CombinedDeviceList({
    required this.avdDevices,
    required this.adbDevices,
  });

  final List<AvdDevice> avdDevices;
  final List<AdbDevice> adbDevices;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Physical (ADB) devices ----
        if (adbDevices.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.smartphone,
            title: "Physical Devices",
            count: adbDevices.length,
          ),
          const SizedBox(height: 8),
          for (final device in adbDevices) ...[
            AdbDeviceCard(
              device: device,
              onDisconnect: () => context
                  .read<DeviceProvider>()
                  .disconnectDevice(device.serial),
            ),
            const SizedBox(height: 8),
          ],
          if (avdDevices.isNotEmpty) const SizedBox(height: 16),
        ],

        // ---- Virtual (AVD) devices ----
        if (avdDevices.isNotEmpty) ...[
          if (adbDevices.isNotEmpty)
            _SectionHeader(
              icon: Icons.devices,
              title: "Virtual Devices",
              count: avdDevices.length,
            ),
          if (adbDevices.isNotEmpty) const SizedBox(height: 8),
          for (int i = 0; i < avdDevices.length; i++) ...[
            _buildAvdCard(context, avdDevices[i]),
            if (i < avdDevices.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildAvdCard(BuildContext context, AvdDevice device) {
    return DeviceCard(
      device: device,
      onStart: () => context.read<DeviceProvider>().startDevice(device.name),
      onColdBoot: () => context.read<DeviceProvider>().startDevice(
        device.name,
        coldBoot: true,
      ),
      onStop: () => context.read<DeviceProvider>().stopDevice(device.name),
      onDelete: () => _confirmDelete(context, device.name),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete AVD?"),
        content: Text(
          'Are you sure you want to delete "$name"?\n'
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<DeviceProvider>().deleteDevice(name);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.sdkReady});

  final bool sdkReady;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smartphone_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            sdkReady ? "No devices found." : "Android SDK not found.",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            sdkReady
                ? 'Tap "New Device" to create an AVD, or use Wireless ADB to connect a phone.'
                : "Use the banner above to install the SDK.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SdkNotFoundBanner extends StatelessWidget {
  const _SdkNotFoundBanner({required this.provider});

  final DeviceProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Android SDK not found on this system.",
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            FilledButton(
              onPressed: provider.installing ? null : provider.installSdk,
              child: const Text("Install SDK"),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InstallProgressBanner extends StatelessWidget {
  const _InstallProgressBanner({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress < 0 ? null : progress),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: scheme.onErrorContainer),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

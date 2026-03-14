import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../models/avd_device.dart";
import "../providers/device_provider.dart";
import "../widgets/device_card.dart";
import "create_device_screen.dart";

/// Main screen: shows the list of AVDs and SDK-not-found banner when needed.
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
        title: const Text("flavd – AVD Manager"),
        actions: [
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
                    : provider.devices.isEmpty
                        ? _EmptyState(sdkReady: provider.sdkReady)
                        : _DeviceList(devices: provider.devices),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DeviceProvider>(
        builder: (context, provider, _) => FloatingActionButton.extended(
          onPressed: provider.sdkReady
              ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const CreateDeviceScreen(),
                    ),
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

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<AvdDevice> devices;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final device = devices[i];
        return DeviceCard(
          device: device,
          onStart: () => context.read<DeviceProvider>().startDevice(device.name),
          onStop: () => context.read<DeviceProvider>().stopDevice(device.name),
          onDelete: () => _confirmDelete(context, device.name),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete AVD?"),
        content: Text('Are you sure you want to delete "$name"?\n'
            "This action cannot be undone."),
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
            sdkReady ? "No virtual devices yet." : "Android SDK not found.",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            sdkReady
                ? 'Tap "New Device" to create your first AVD.'
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
            Icon(Icons.warning_amber_rounded, color: scheme.onSecondaryContainer),
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
  const _InstallProgressBanner(
      {required this.message, required this.progress});

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
          LinearProgressIndicator(
            value: progress < 0 ? null : progress,
          ),
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
                style: TextStyle(
                    color: scheme.onErrorContainer, fontSize: 13),
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

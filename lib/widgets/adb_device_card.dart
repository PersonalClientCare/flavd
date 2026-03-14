import "package:flutter/material.dart";

import "package:flavd/models/adb_device.dart";

/// Card widget representing a single physical ADB device in the device list.
class AdbDeviceCard extends StatelessWidget {
  const AdbDeviceCard({
    super.key,
    required this.device,
    required this.onDisconnect,
  });

  final AdbDevice device;

  /// Called when the user confirms disconnection of a wireless device.
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status indicator + icon.
            _StatusIcon(device: device),
            const SizedBox(width: 14),

            // Device info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitle(context),
                ],
              ),
            ),

            // State chip.
            _StateChip(state: device.state),
            const SizedBox(width: 8),

            // Actions.
            if (device.isWireless)
              IconButton(
                icon: Icon(Icons.link_off, color: colorScheme.error),
                tooltip: "Disconnect wireless device",
                onPressed: () => _confirmDisconnect(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (device.serial.isNotEmpty) parts.add(device.serial);
    if (device.product != null) parts.add(device.product!);
    if (device.isWireless) {
      parts.add("Wi-Fi");
    } else {
      parts.add("USB");
    }

    return Text(
      parts.join("  ·  "),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  void _confirmDisconnect(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Disconnect device?"),
        content: Text(
          'Disconnect wireless device "${device.displayName}" '
          "(${device.serial})?",
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
              onDisconnect();
            },
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.device});

  final AdbDevice device;

  @override
  Widget build(BuildContext context) {
    final isOnline = device.state == AdbDeviceState.device;
    final color = isOnline
        ? const Color(0xFF4CAF50) // green
        : device.state == AdbDeviceState.unauthorized
        ? Colors.orange
        : Theme.of(context).colorScheme.outlineVariant;

    final iconData = device.isWireless ? Icons.wifi : Icons.usb;

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(iconData, size: 36, color: color),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final AdbDeviceState state;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (state) {
      AdbDeviceState.device => (
        const Color(0xFF4CAF50).withValues(alpha: 0.15),
        const Color(0xFF2E7D32),
      ),
      AdbDeviceState.unauthorized => (
        Colors.orange.withValues(alpha: 0.15),
        Colors.orange.shade800,
      ),
      AdbDeviceState.offline => (
        Colors.grey.withValues(alpha: 0.15),
        Colors.grey.shade700,
      ),
      _ => (Colors.grey.withValues(alpha: 0.15), Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

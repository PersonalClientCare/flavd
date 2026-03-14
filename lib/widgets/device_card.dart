import 'package:flutter/material.dart';

import '../models/avd_device.dart';

/// Card widget representing a single AVD in the device list.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onStart,
    required this.onStop,
    required this.onDelete,
  });

  final AvdDevice device;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDelete;

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
            _StatusIndicator(isRunning: device.isRunning),
            const SizedBox(width: 14),

            // Device info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitle(context),
                ],
              ),
            ),

            // Actions.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (device.isRunning)
                  _ActionButton(
                    icon: Icons.stop_circle_outlined,
                    tooltip: 'Stop emulator',
                    color: colorScheme.error,
                    onPressed: onStop,
                  )
                else
                  _ActionButton(
                    icon: Icons.play_circle_outline,
                    tooltip: 'Start emulator',
                    color: colorScheme.primary,
                    onPressed: onStart,
                  ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete AVD',
                  color: colorScheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final parts = <String>[];
    if (device.basedOn != null) parts.add(device.basedOn!);
    if (device.tagAbi != null) parts.add(device.tagAbi!);
    if (parts.isEmpty && device.target != null) parts.add(device.target!);

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      parts.join('  ·  '),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final color = isRunning
        ? const Color(0xFF4CAF50)  // green
        : Theme.of(context).colorScheme.outlineVariant;

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          isRunning ? Icons.smartphone : Icons.smartphone_outlined,
          size: 36,
          color: color,
        ),
        if (isRunning)
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

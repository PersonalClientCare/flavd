import "package:flutter/material.dart";

/// A scrollable log output pane that shows lines streamed from a process.
class LogOutputWidget extends StatelessWidget {
  const LogOutputWidget({
    super.key,
    required this.lines,
    this.maxHeight = 220,
  });

  final List<String> lines;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lines.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: lines.length,
            itemBuilder: (_, i) => _LogLine(line: lines[i]),
          ),
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final isError = line.toLowerCase().startsWith("error");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: "monospace",
          fontSize: 12,
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

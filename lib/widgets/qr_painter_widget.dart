import "package:flutter/material.dart";
import "package:qr/qr.dart";

/// Renders a QR code from a [data] string using Flutter's [CustomPainter].
///
/// Uses the `qr` package to generate the QR module matrix and paints it
/// onto a square canvas with configurable colours and quiet zone.
class QrPainterWidget extends StatelessWidget {
  const QrPainterWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.moduleColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.quietZoneModules = 2,
    this.errorCorrectLevel = QrErrorCorrectLevel.M,
    this.borderRadius = 12.0,
  });

  /// The string to encode as a QR code.
  final String data;

  /// Widget size (width and height) in logical pixels.
  final double size;

  /// Colour used for dark (data) modules.
  final Color moduleColor;

  /// Background colour (light modules + quiet zone).
  final Color backgroundColor;

  /// Number of empty modules around the QR code (quiet zone).
  final int quietZoneModules;

  /// QR error correction level (L / M / Q / H).
  final int errorCorrectLevel;

  /// Border radius applied to the container that clips the QR code.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: errorCorrectLevel,
    );
    final qrImage = QrImage(qrCode);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor,
        child: CustomPaint(
          size: Size(size, size),
          painter: _QrCodePainter(
            qrImage: qrImage,
            moduleColor: moduleColor,
            backgroundColor: backgroundColor,
            quietZoneModules: quietZoneModules,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _QrCodePainter extends CustomPainter {
  _QrCodePainter({
    required this.qrImage,
    required this.moduleColor,
    required this.backgroundColor,
    required this.quietZoneModules,
  });

  final QrImage qrImage;
  final Color moduleColor;
  final Color backgroundColor;
  final int quietZoneModules;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleCount = qrImage.moduleCount;

    // Total modules including quiet zone on each side.
    final totalModules = moduleCount + quietZoneModules * 2;

    // Size of a single module in pixels.
    final moduleSize = size.width / totalModules;

    // Fill background (quiet zone + light modules).
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Paint dark modules.
    final darkPaint = Paint()
      ..color = moduleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          final x = (col + quietZoneModules) * moduleSize;
          final y = (row + quietZoneModules) * moduleSize;

          // Use ceil on width/height to avoid sub-pixel gaps between modules.
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              moduleSize.ceilToDouble(),
              moduleSize.ceilToDouble(),
            ),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrCodePainter oldDelegate) =>
      oldDelegate.qrImage != qrImage ||
      oldDelegate.moduleColor != moduleColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.quietZoneModules != quietZoneModules;
}

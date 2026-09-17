import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design.dart';
import '../../core/localization.dart';

/// Opens the camera and returns the first product barcode it sees, or null
/// if the user backs out.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Only the retail formats: a QR code on a leaflet is not a product.
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code == null || code.isEmpty) continue;
      _done = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    // A wide, short window: barcodes are wide and short.
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.8,
      height: size.width * 0.45,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(l10n.scanTitle),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.lightbulb, size: 18),
            tooltip: l10n.scanTorch,
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: window,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? l10n.scanNoPermission
                  : l10n.scanUnavailable,
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _WindowPainter(window))),
          Positioned(
            left: Insets.xl,
            right: Insets.xl,
            top: window.bottom + Insets.xl,
            child: Text(
              l10n.scanHint,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything but the scan window and outlines it.
class _WindowPainter extends CustomPainter {
  final Rect window;

  _WindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(window, const Radius.circular(16));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(frame),
      ),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window;
}

class _ScannerError extends StatelessWidget {
  final String message;

  const _ScannerError({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                FontAwesomeIcons.cameraRotate,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: Insets.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

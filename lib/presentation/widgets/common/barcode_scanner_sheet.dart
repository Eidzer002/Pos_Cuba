// lib/presentation/widgets/common/barcode_scanner_sheet.dart
// Escáner de código de barras reutilizable — bottom sheet con cámara.
// Uso: final code = await showBarcodeScannerSheet(context);

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Abre un bottom sheet con la cámara lista para escanear.
/// Devuelve el valor del código detectado, o null si el usuario cancela.
Future<String?> showBarcodeScannerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _BarcodeScannerSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.65,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Cámara ────────────────────────────────────────────────────
            MobileScanner(
              onDetect: (capture) {
                if (_detected) return;
                final code = capture.barcodes
                    .where((b) => b.rawValue != null)
                    .map((b) => b.rawValue!)
                    .toList();
                if (code.isEmpty) return;
                _detected = true;
                Navigator.pop(context, code.first);
              },
            ),

            // ── Overlay con ventana de escaneo ────────────────────────────
            const _ScanOverlay(),

            // ── Botón cerrar ──────────────────────────────────────────────
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cancelar',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // ── Instrucción ───────────────────────────────────────────────
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Apunta al código de barras',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay semitransparente con ventana rectangular y esquinas verdes
// ─────────────────────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OverlayPainter(), size: Size.infinite);
}

class _OverlayPainter extends CustomPainter {
  static const double _winW = 260;
  static const double _winH = 160;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - _winW) / 2;
    final top  = (size.height - _winH) / 2 - 20;
    final rect = Rect.fromLTWH(left, top, _winW, _winH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Fondo oscuro perforado
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      Paint()..color = Colors.black.withOpacity(0.55),
    );

    // Borde blanco de la ventana
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Esquinas verdes
    const cLen = 22.0;
    final cp = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final tl = Offset(left, top);
    final tr = Offset(left + _winW, top);
    final bl = Offset(left, top + _winH);
    final br = Offset(left + _winW, top + _winH);

    // Arriba-izquierda
    canvas.drawLine(tl, tl + const Offset(cLen, 0), cp);
    canvas.drawLine(tl, tl + const Offset(0, cLen), cp);
    // Arriba-derecha
    canvas.drawLine(tr, tr - const Offset(cLen, 0), cp);
    canvas.drawLine(tr, tr + const Offset(0, cLen), cp);
    // Abajo-izquierda
    canvas.drawLine(bl, bl + const Offset(cLen, 0), cp);
    canvas.drawLine(bl, bl - const Offset(0, cLen), cp);
    // Abajo-derecha
    canvas.drawLine(br, br - const Offset(cLen, 0), cp);
    canvas.drawLine(br, br - const Offset(0, cLen), cp);
  }

  @override
  bool shouldRepaint(_) => false;
}

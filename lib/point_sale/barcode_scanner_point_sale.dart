import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPointSalePage extends StatefulWidget {
  const BarcodeScannerPointSalePage({Key? key}) : super(key: key);

  @override
  _BarcodeScannerPointSalePageState createState() =>
      _BarcodeScannerPointSalePageState();
}

class _BarcodeScannerPointSalePageState
    extends State<BarcodeScannerPointSalePage> {
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void dispose() {
    _cameraController.dispose(); // Liberar recursos de la cámara
    super.dispose();
  }

  void _handleScanned(String scannedCode) {
    Get.back(result: {'barcode': scannedCode});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Escanear código de barras"),
        actions: [
          // Botón para encender/apagar la linterna
          IconButton(
            icon: Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Vista de la cámara para escanear el código
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String barcode = barcodes.first.rawValue ?? "";
                _handleScanned(barcode);
              }
            },
          ),

          // Guía visual (overlay) en la cámara
          Positioned.fill(
            child: CustomPaint(
              painter: BarcodeOverlayPainter(),
            ),
          ),

          // Botón para cerrar la cámara
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context, null), // Cerrar sin datos
            ),
          ),
        ],
      ),
    );
  }
}

class BarcodeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final double guideWidth = size.width * 0.8;
    final double guideHeight = 100;
    final double left = (size.width - guideWidth) / 2;
    final double top = (size.height - guideHeight) / 2;

    final Rect guideRect = Rect.fromLTWH(left, top, guideWidth, guideHeight);
    canvas.drawRect(guideRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onScan; // Función para devolver el código escaneado

  const BarcodeScannerPage({Key? key, required this.onScan}) : super(key: key);

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void dispose() {
    _cameraController.dispose(); // Liberar recursos de la cámara
    super.dispose();
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
                final String barcode = barcodes.first.rawValue ??
                    ""; // Obtener el valor del código
                widget.onScan(barcode); // Devolver el código escaneado
                Navigator.pop(context); // Cerrar la página de escaneo
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
              onPressed: () => Navigator.pop(context),
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
      ..color = Colors.white.withOpacity(0.5) // Borde semitransparente
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

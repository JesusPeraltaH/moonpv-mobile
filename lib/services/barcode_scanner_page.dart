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
      body: MobileScanner(
        controller: _cameraController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String barcode =
                barcodes.first.rawValue ?? ""; // Obtener el valor del código
            widget.onScan(barcode); // Devolver el código escaneado
            Navigator.pop(context); // Cerrar la página de escaneo
          }
        },
      ),
    );
  }
}

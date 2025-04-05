import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EscaneoCodigoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Escaneando código')),
      body: MobileScanner(
  onDetect: (BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        Navigator.pop(context, code);
      }
    }
  },
)
    );
  }
}

import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class PrintingService {
  static final PrintingService _instance = PrintingService._internal();
  factory PrintingService() => _instance;
  PrintingService._internal();

  // Function to handle Spanish characters for thermal printers
  String _fixSpanishCharacters(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U');
  }

  Future<void> printSaleTicket({
    required List<Map<String, dynamic>> saleDetails,
    required double grandTotal,
    required double receivedAmount,
    required double changeAmount,
    required String currency,
    required String businessName,
    required String cashierName,
  }) async {
    try {
      // ESC Command for thermal printer
      final escCommand = EscCommand();
      await escCommand.cleanCommand();

      // Load and print the Moon logo with reduced size
      try {
        final ByteData bytes = await rootBundle
            .load("assets/images/moon_solo_negro_recortada_fondo_blanco.jpg");
        final Uint8List originalImage = bytes.buffer.asUint8List();

        // Decode the image to get its dimensions
        final codec = await ui.instantiateImageCodec(originalImage);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        // Calculate new dimensions (reduce to half size)
        final int newWidth = (image.width * 0.5).round();
        final int newHeight = (image.height * 0.5).round();

        // Resize the image
        final resizedImage = await _resizeImage(image, newWidth, newHeight);

        // Convert back to Uint8List
        final resizedBytes =
            await resizedImage.toByteData(format: ui.ImageByteFormat.png);
        final resizedUint8List = resizedBytes!.buffer.asUint8List();

        await escCommand.image(image: resizedUint8List);
      } catch (e) {
        print('Error loading or processing logo: $e');
        // Continue without logo if there's an error
      }

      // Build the ticket content with proper encoding
      StringBuffer ticketContent = StringBuffer();

      // Header with proper spacing and fixed characters
      ticketContent.writeln('');
      ticketContent.writeln(_fixSpanishCharacters(businessName));
      ticketContent.writeln('TICKET DE VENTA');
      ticketContent.writeln(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      ticketContent.writeln('Cajero: ${_fixSpanishCharacters(cashierName)}');
      ticketContent.writeln('--------------------------------');
      ticketContent.writeln('PRODUCTOS:');

      // Products
      for (var product in saleDetails) {
        double precio = (product['precio'] as num?)?.toDouble() ?? 0.0;
        int cantidad = (product['cantidad'] as num?)?.toInt() ?? 0;
        double total = precio * cantidad;

        ticketContent.writeln(_fixSpanishCharacters(product['nombre'] ?? ''));
        ticketContent.writeln(
            '  ${cantidad} x \$${precio.toStringAsFixed(2)} = \$${total.toStringAsFixed(2)}');
      }

      // Totals
      ticketContent.writeln('--------------------------------');
      ticketContent.writeln('TOTAL: \$${grandTotal.toStringAsFixed(2)}');
      ticketContent.writeln('RECIBIDO: \$${receivedAmount.toStringAsFixed(2)}');
      ticketContent.writeln('CAMBIO: \$${changeAmount.toStringAsFixed(2)}');
      ticketContent.writeln('--------------------------------');
      ticketContent.writeln('¡GRACIAS POR SU COMPRA!');
      ticketContent.writeln('Vuelva pronto');

      // Print the ticket content
      await escCommand.text(content: ticketContent.toString());
      await escCommand.print();

      final escCmd = await escCommand.getCommand();
      if (escCmd != null) {
        await BluetoothPrintPlus.write(escCmd);
      }
    } catch (e) {
      print('Error printing ticket: $e');
      rethrow;
    }
  }

  Future<ui.Image> _resizeImage(
      ui.Image image, int newWidth, int newHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the resized image
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(newWidth, newHeight);
  }

  Future<void> printTestTicket() async {
    try {
      final escCommand = EscCommand();
      await escCommand.cleanCommand();

      // Load and print the Moon logo with reduced size
      try {
        final ByteData bytes = await rootBundle
            .load("assets/images/moon_solo_negro_recortada_fondo_blanco.jpg");
        final Uint8List originalImage = bytes.buffer.asUint8List();

        // Decode the image to get its dimensions
        final codec = await ui.instantiateImageCodec(originalImage);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        // Calculate new dimensions (reduce to half size)
        final int newWidth = (image.width * 0.5).round();
        final int newHeight = (image.height * 0.5).round();

        // Resize the image
        final resizedImage = await _resizeImage(image, newWidth, newHeight);

        // Convert back to Uint8List
        final resizedBytes =
            await resizedImage.toByteData(format: ui.ImageByteFormat.png);
        final resizedUint8List = resizedBytes!.buffer.asUint8List();

        await escCommand.image(image: resizedUint8List);
      } catch (e) {
        print('Error loading or processing logo: $e');
        // Continue without logo if there's an error
      }

      // Build test ticket content
      StringBuffer testContent = StringBuffer();
      testContent.writeln('');
      testContent.writeln('TEST DE IMPRESORA');
      testContent.writeln(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
      testContent.writeln('Impresora funcionando correctamente');

      // Print the test content
      await escCommand.text(content: testContent.toString());
      await escCommand.print();

      final escCmd = await escCommand.getCommand();
      if (escCmd != null) {
        await BluetoothPrintPlus.write(escCmd);
      }
    } catch (e) {
      print('Error printing test ticket: $e');
      rethrow;
    }
  }
}

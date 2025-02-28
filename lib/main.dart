import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
//import 'package:blue_thermal_printer/blue_thermal_printer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Moon PV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SalespointNewSalePage(),
    );
  }
}

class BluetoothInfo {
  late String name;
  late String macAddress; // Cambié 'macAdress' a 'macAddress'
  //late BluetoothDevice device; Agrega una referencia al dispositivo Bluetooth
}

// Función para obtener los dispositivos Bluetooth emparejados
// Future<List<BluetoothInfo>> getPairedBluetooths() async {
//   BlueThermalPrinter printer = BlueThermalPrinter.instance;
//   List<BluetoothDevice> devices = await printer.getBondedDevices();

//   return devices.map((device) {
//     return BluetoothInfo()
//       ..name =
//           device.name ?? 'Desconocido' // Proporciona un valor predeterminado
//       ..macAddress =
//           device.address ?? 'Desconocido' // Proporciona un valor predeterminado
//       ..device = device; // Guarda el dispositivo Bluetooth
//   }).toList();
// }

// Función para conectar a la impresora
// Future<void> connectPrinter(BluetoothDevice device) async {
//   BlueThermalPrinter printer = BlueThermalPrinter.instance;
//   await printer.connect(device);
//   print("Impresora conectada: ${device.name}");
// }

// Función para enviar datos de impresión a la impresora conectada
// Future<void> printText(String text) async {
//   BlueThermalPrinter printer = BlueThermalPrinter.instance;
//   List<BluetoothDevice> devices = await printer.getBondedDevices();

//   if (devices.isNotEmpty) {
//     await printer.connect(devices[0]); // Conectar al primer dispositivo
//     await printer.printCustom(text, 1, 1); // Imprimir texto
//     await printer.disconnect(); // Desconectar después de imprimir
//   } else {
//     print("No hay dispositivos Bluetooth disponibles.");
//   }
// }

// Ejemplo de uso en alguna parte de tu código para conectar e imprimir
// Future<void> exampleUsage() async {
//   List<BluetoothInfo> devices = await getPairedBluetooths();
//   if (devices.isNotEmpty) {
//     BluetoothDevice selectedDevice =
//         devices[0].device; // Obtén el dispositivo Bluetooth
//     await connectPrinter(selectedDevice);
//     await printText("¡Hola, Mundo!"); // Enviar texto para imprimir
//   } else {
//     print("No hay impresoras emparejadas.");
//   }
// }

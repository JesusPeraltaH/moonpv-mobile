import 'package:flutter/material.dart';
import 'dart:async';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/services.dart';
import 'point_sale_newpage.dart';

class PrinterConnectionScreen extends StatefulWidget {
  const PrinterConnectionScreen({super.key});

  @override
  State<PrinterConnectionScreen> createState() =>
      _PrinterConnectionScreenState();
}

class _PrinterConnectionScreenState extends State<PrinterConnectionScreen> {
  late StreamSubscription<BlueState> _blueStateSubscription;
  late StreamSubscription<ConnectState> _connectStateSubscription;
  late StreamSubscription<Uint8List> _receivedDataSubscription;
  late StreamSubscription<List<BluetoothDevice>> _scanResultsSubscription;
  late List<BluetoothDevice> _scanResults;
  BluetoothDevice? _device;

  @override
  void initState() {
    super.initState();
    _scanResults = [];
    initBluetoothPrintPlusListen();
  }

  @override
  void dispose() {
    super.dispose();
    _blueStateSubscription.cancel();
    _connectStateSubscription.cancel();
    _receivedDataSubscription.cancel();
    _scanResultsSubscription.cancel();
    _scanResults.clear();
  }

  Future<void> initBluetoothPrintPlusListen() async {
    /// listen scanResults
    _scanResultsSubscription = BluetoothPrintPlus.scanResults.listen((event) {
      if (mounted) {
        setState(() {
          _scanResults = event;
        });
      }
    });

    /// listen blue state
    _blueStateSubscription = BluetoothPrintPlus.blueState.listen((event) {
      print('********** blueState change: $event **********');
      if (mounted) {
        setState(() {});
      }
    });

    /// listen connect state
    _connectStateSubscription = BluetoothPrintPlus.connectState.listen((event) {
      print('********** connectState change: $event **********');
      switch (event) {
        case ConnectState.connected:
          if (_device != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const SalespointNewSalePage()),
            );
          }
          break;
        case ConnectState.disconnected:
          if (_device != null) {
            _device = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Desconectado del dispositivo')),
            );
          }
          break;
      }
    });

    /// listen received data
    _receivedDataSubscription = BluetoothPrintPlus.receivedData.listen((data) {
      print('********** received data: $data **********');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión de Impresora'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: BluetoothPrintPlus.isBlueOn
            ? Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(Icons.print,
                            color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Dispositivos disponibles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scanned Devices
                  Expanded(
                    child: _scanResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bluetooth_searching,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron dispositivos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Presiona el botón de búsqueda para escanear',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _scanResults.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (context, index) {
                              return _buildDeviceItem(
                                  context, _scanResults[index]);
                            },
                          ),
                  ),
                ],
              )
            : buildBlueOffWidget(),
      ),
      floatingActionButton:
          BluetoothPrintPlus.isBlueOn ? buildScanButton(context) : null,
    );
  }

  Widget buildBlueOffWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 64.0,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bluetooth está desactivado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor, activa el Bluetooth para continuar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildScanButton(BuildContext context) {
    if (BluetoothPrintPlus.isScanningNow) {
      return FloatingActionButton.extended(
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.stop),
        label: const Text('Detener búsqueda'),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: onScanPressed,
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.search),
        label: const Text('Buscar dispositivos'),
      );
    }
  }

  Widget _buildDeviceItem(BuildContext context, BluetoothDevice device) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.print,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          device.address,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            _device = device;
            await BluetoothPrintPlus.connect(device);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text("Conectar"),
        ),
      ),
    );
  }

  Future onScanPressed() async {
    try {
      await BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("onScanPressed error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar la búsqueda: $e')),
        );
      }
    }
  }

  Future onStopPressed() async {
    try {
      await BluetoothPrintPlus.stopScan();
    } catch (e) {
      print("onStopPressed error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al detener la búsqueda: $e')),
        );
      }
    }
  }
}

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonpv/conteo/scannerCodigo.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ConteoEscaneoScreen extends StatefulWidget {
  final List<String> negociosSeleccionados; 
  // Lista de IDs de negocios seleccionados
  final String csvPath;

  const ConteoEscaneoScreen({required this.negociosSeleccionados, required this.csvPath});

  @override
  _ConteoEscaneoScreenState createState() => _ConteoEscaneoScreenState();
}

class _ConteoEscaneoScreenState extends State<ConteoEscaneoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> productos = [];
  TextEditingController cantidadController = TextEditingController();
String codigoEscaneado = '';
  bool scanning = true;
   bool isCsvLoaded = false;
  bool isLoading = true;
  bool isBottomSheetOpen = false; // Nuevo estado para controlar el bottom sheet
  MobileScannerController cameraController = MobileScannerController();
  String _nombreArchivo = '';
String _mesSeleccionado = 'Enero';
final List<String> _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];


  @override
  void initState() {
    super.initState();
    // Cargar productos de los negocios seleccionados
    _loadProductos();
     _initializeData();
    _loadCsvData().then((_) {
      setState(() {
        isLoading = false;
        isCsvLoaded = true;
      });
    });
  }

  String _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'usuario_no_autenticado';
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadProductos(),
        _loadCsvData(),
      ]);
      
      setState(() {
        isLoading = false;
        isCsvLoaded = true;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar datos: $e")),
      );
    }
  }

  // Cargar los productos de los negocios seleccionados
    Future<void> _loadProductos() async {
    for (var negocioId in widget.negociosSeleccionados) {
      final negocioSnapshot = await _firestore.collection('negocios').doc(negocioId).get();
      final negocioData = negocioSnapshot.data();
      
      if (negocioData != null) {
        final productosSnapshot = await _firestore
            .collection('productos')
            .where('negocioid', isEqualTo: negocioId)
            .get();

        for (var productoDoc in productosSnapshot.docs) {
          final productoData = productoDoc.data();
          productos.add({
            'nombreEmpresa': negocioData['nombreEmpresa'],
            'codigo': productoData['codigo'],
            'articulo': productoData['nombre'],
            'cantidadExistente': productoData['cantidad'],
            'cantidadActual': 0,
            'productoId': productoDoc.id,
          });
        }
      }
    }
  }
  // Iniciar escaneo
    Future<void> _startScanning() async {
    if (!isCsvLoaded) {
      await _loadCsvData();
    }

    setState(() {
      scanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      scanning = false;
    });
  }

  // Mostrar el BottomSheet con la información del producto
 void _showProductBottomSheet(String scannedCode) {
    if (isBottomSheetOpen) return; // Evitar múltiples bottomsheets

    setState(() {
      isBottomSheetOpen = true;
      scanning = false; // Desactivar escaneo mientras el bottomsheet está abierto
    });

    // Buscar el producto en la lista
    final productoEncontrado = productos.firstWhere(
      (producto) => producto['codigo'].toString() == scannedCode,
      orElse: () => {},
    );

    if (productoEncontrado.isNotEmpty) {
      cantidadController.text = productoEncontrado['cantidadActual'].toString();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return GestureDetector(
            onTap: () {}, // Evitar que se cierre al tocar fuera
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        productoEncontrado['articulo'].toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Código: ${productoEncontrado['codigo']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Existencia: ${productoEncontrado['cantidadExistente']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: cantidadController,
                        keyboardType: TextInputType.number,
                        autofocus: true, // Forzar el foco en el teclado
                        decoration: InputDecoration(
                          labelText: 'Cantidad Actual',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  isBottomSheetOpen = false;
                                  scanning = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              child: const Text('CANCELAR'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final cantidadActual = int.tryParse(cantidadController.text) ?? 0;
                                setState(() {
                                  productoEncontrado['cantidadActual'] = cantidadActual;
                                  isBottomSheetOpen = false;
                                  scanning = true;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('GUARDAR'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ).then((_) {
        if (mounted) {
          setState(() {
            isBottomSheetOpen = false;
            scanning = true;
          });
        }
      });
    } else {
      setState(() {
        isBottomSheetOpen = false;
        scanning = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto con código $scannedCode no encontrado')),
      );
    }
  }
  // Detener el conteo y guardar el CSV
Future<void> _detenerConteo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/ConteoNegocios_$timestamp.csv');
      
      final csvData = [
        ['Nombre Negocio', 'Código', 'Artículo', 'Existencia', 'Actual'],
        ...productos.map((p) => [
          p['nombreEmpresa'],
          p['codigo'],
          p['articulo'],
          p['cantidadExistente'],
          p['cantidadActual'],
        ]),
      ];

      await file.writeAsString(const ListToCsvConverter().convert(csvData));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conteo guardado exitosamente")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e")),
      );
    }
  }

 Future<void> _loadCsvData() async {
    try {
      final input = File(widget.csvPath).openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      if (fields.isNotEmpty && fields[0].isNotEmpty) {
        List<Map<String, dynamic>> csvProductos = [];

        for (var row in fields.sublist(1)) {
          if (row.length >= 5) {
            csvProductos.add({
              'nombreEmpresa': row[0],
              'codigo': row[1],
              'articulo': row[2],
              'cantidadExistente': int.tryParse(row[3].toString()) ?? 0,
              'cantidadActual': 0,
            });
          }
        }

        setState(() {
          productos = csvProductos;
        });
      }
    } catch (e) {
      throw Exception("Error al cargar CSV: $e");
    }
  }

// Método para editar cantidad manualmente
  Future<void> _editProductQuantity(Map<String, dynamic> producto) async {
    cantidadController.text = producto['cantidadActual'].toString();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar cantidad'),
        content: TextField(
          controller: cantidadController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad actual',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final cantidad = int.tryParse(cantidadController.text) ?? 0;
              setState(() {
                producto['cantidadActual'] = cantidad;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoGuardado() async {
  final formKey = GlobalKey<FormState>();
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Guardar conteo'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nombre del archivo',
                  hintText: 'Ej: Inventario Tienda Central'
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
                onChanged: (value) => _nombreArchivo = value,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _mesSeleccionado,
                items: _meses.map((String mes) {
                  return DropdownMenuItem<String>(
                    value: mes,
                    child: Text(mes),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _mesSeleccionado = newValue!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Mes del inventario'
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context);
              await _guardarConteoCompleto();
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

// Función mejorada para guardar el conteo
Future<void> _guardarConteoCompleto() async {
  // Mostrar indicador de carga
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nombreArchivo = '${_nombreArchivo.replaceAll(' ', '_')}_$timestamp.csv';
    
    // 1. Guardar archivo localmente
    final csvData = [
      ['Nombre Negocio', 'Código', 'Artículo', 'Existencia', 'Actual'],
      ...productos.map((p) => [
        p['nombreEmpresa'],
        p['codigo'],
        p['articulo'],
        p['cantidadExistente'],
        p['cantidadActual'],
      ]),
    ];

    final file = File('${directory.path}/$nombreArchivo');
    await file.writeAsString(const ListToCsvConverter().convert(csvData));

    // 2. Subir a Firebase Storage
    final storage = FirebaseStorage.instance;
    final storageRef = storage.ref().child('inventarios/$nombreArchivo');
    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    // 3. Guardar metadatos en Firestore
    await _firestore.collection('conteos').add({
      'nombre': _nombreArchivo,
      'mes': _mesSeleccionado,
      'fecha': FieldValue.serverTimestamp(),
      'url': downloadUrl,
      'estatus': 'finished',
      'negocios': widget.negociosSeleccionados,
      'userId': _firestore.doc('users/${_getCurrentUserId()}'), // Ajusta según tu auth
    });

    // 4. Actualizar estado de los productos si es necesario
    // (Agrega aquí la lógica para actualizar productos si lo necesitas)

    if (!mounted) return;
    Navigator.pop(context); // Cerrar diálogo de carga
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conteo guardado exitosamente')),
    );

    // Opcional: Navegar a pantalla anterior
    // Navigator.pop(context);

  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context); // Cerrar diálogo de carga
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al guardar: $e')),
    );
  }
}

// Función para pausar el conteo
Future<void> _pausarConteo() async {
  try {
    // Guardar estado intermedio si es necesario
    await _firestore.collection('conteos').add({
      'fecha': FieldValue.serverTimestamp(),
      'estatus': 'paused',
      'negocios': widget.negociosSeleccionados,
      'usuario': _firestore.doc('usuarios/${_getCurrentUserId()}'),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conteo pausado')),
    );

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al pausar: $e')),
    );
  }
}

// Actualiza tu floatingActionButton:


// Método para detener el escaneo
 Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Preparando escáner...")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Cargando datos del inventario..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conteo Escaneo"),
        actions: [
          IconButton(
            icon: Icon(scanning ? Icons.pause : Icons.play_arrow),
            onPressed: scanning ? _stopScanning : _startScanning,
            tooltip: scanning ? 'Pausar escaneo' : 'Continuar escaneo',
          ),
        ],
      ),
      body: Column(
        children: [
          if (scanning) ...[
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.normal,
                      facing: CameraFacing.back,
                      torchEnabled: false,
                    ),
                    onDetect: (BarcodeCapture capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && scanning) {
                        final code = barcodes.first.rawValue;
                        if (code != null) {
                          setState(() => codigoEscaneado = code);
                          _showProductBottomSheet(code);
                        }
                      }
                    },
                  ),
                  // Overlay de guía para escaneo
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 250,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Enfoque el código aquí',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Indicador de código escaneado
                  if (codigoEscaneado.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.black.withOpacity(0.7),
                        child: Text(
                          'Último código: $codigoEscaneado',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          Expanded(
            flex: scanning ? 3 : 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Productos en inventario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total: ${productos.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (!isCsvLoaded)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Cargando lista de productos..."),
                          ],
                        ),
                      ),
                    )
                  else if (productos.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          "No se encontraron productos",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final producto = productos[index];
                          final isScanned = producto['cantidadActual'] > 0;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            color: isScanned ? Colors.green[50] : Colors.white,
                            child: ListTile(
                              leading: Icon(
                                isScanned ? Icons.check_circle : Icons.circle_outlined,
                                color: isScanned ? Colors.green : Colors.grey,
                              ),
                              title: Text(
                                producto['articulo'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Código: ${producto['codigo']}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text('Existencia: '),
                                      Text(
                                        '${producto['cantidadExistente']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      const Text('Escaneados: '),
                                      Text(
                                        '${producto['cantidadActual']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isScanned
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!scanning)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startScanning,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'INICIAR ESCANEO',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    FloatingActionButton(
      heroTag: 'btn_pausar',
      onPressed: _pausarConteo,
      tooltip: 'Pausar conteo',
      backgroundColor: Colors.orange,
      child: const Icon(Icons.pause),
    ),
    const SizedBox(height: 10),
    FloatingActionButton.extended(
      heroTag: 'btn_guardar',
      onPressed: _mostrarDialogoGuardado,
      icon: const Icon(Icons.save),
      label: const Text('Guardar Conteo'),
      backgroundColor: Colors.green,
    ),
  ],
),
    );
  }

}




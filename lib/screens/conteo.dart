import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:moonpv/conteo/conteoScanner.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class ConteoNegociosScreen extends StatefulWidget {


  final List<String> negociosSeleccionados;
 ConteoNegociosScreen({Key? key, required this.negociosSeleccionados}) : super(key: key);

  @override
  _ConteoNegociosScreenState createState() => _ConteoNegociosScreenState();
}

class _ConteoNegociosScreenState extends State<ConteoNegociosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> negociosSeleccionados = [];
    List<Map<String, dynamic>> _conteosPendientes = [];
  List<Map<String, dynamic>> _conteosTerminados = [];
  bool _loadingConteos = true;

 @override
  void initState() {
    super.initState();
    _cargarConteos();
  }
   
Future<void> _generarCSV() async {
  // Mostrar diálogo de carga
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );

  try {
    // 1. Preparar la estructura del CSV
    List<List<String>> csvRows = [
      ["Nombre Negocio", "Código", "Artículo", "Cantidad en existencia", "Cantidad actual"]
    ];

    // 2. Procesar cada negocio seleccionado
    for (String negocioId in widget.negociosSeleccionados) {
      // Obtener datos del negocio
      final negocioDoc = await _firestore.collection('negocios').doc(negocioId).get();
      
      if (!negocioDoc.exists) {
        print('Negocio con ID $negocioId no encontrado');
        continue;
      }

      final negocioData = negocioDoc.data() as Map<String, dynamic>;
      final nombreEmpresa = negocioData['nombreEmpresa'] ?? 'Sin nombre';

      // Obtener productos del negocio
      final productosSnapshot = await _firestore
          .collection('productos') // Asegúrate que es 'productos' y no 'products'
          .where('negocioId', isEqualTo: negocioId)
          .get();

      // Verificar si hay productos
      if (productosSnapshot.docs.isEmpty) {
        print('No se encontraron productos para el negocio $nombreEmpresa');
        continue;
      }

      // 3. Agregar cada producto al CSV
      for (var doc in productosSnapshot.docs) {
        final producto = doc.data();
        
        // Validar campos requeridos
        if (producto['codigo'] == null || producto['nombre'] == null || producto['cantidad'] == null) {
          print('Producto con datos incompletos: ${doc.id}');
          continue;
        }

        csvRows.add([
          nombreEmpresa,
          producto['codigo'].toString(),
          producto['nombre'].toString(),
          producto['cantidad'].toString(),
          '0' // Cantidad actual inicializada en 0
        ]);
      }
    }

    // 4. Verificar que hay datos para guardar
    if (csvRows.length <= 1) {
      throw Exception('No se encontraron productos para generar el CSV');
    }

    // 5. Crear el archivo CSV localmente
    final csvContent = const ListToCsvConverter().convert(csvRows);
    final directory = await getApplicationDocumentsDirectory();
    final inventariosDir = Directory('${directory.path}/inventarios');
    
    // Crear directorio si no existe
    if (!await inventariosDir.exists()) {
      await inventariosDir.create(recursive: true);
    }
    
    final localPath = "${inventariosDir.path}/conteo_${DateTime.now().millisecondsSinceEpoch}.csv";
    final localFile = File(localPath);
    await localFile.writeAsString(csvContent);
    print('CSV creado localmente en: $localPath');

    // 6. Subir a Firebase Storage
    final storage = FirebaseStorage.instance;
    final storageRef = storage.ref().child('inventarios/conteo_${DateTime.now().millisecondsSinceEpoch}.csv');
    
    // Actualizar UI para mostrar progreso de subida
    Navigator.of(context).pop(); // Cerrar diálogo anterior
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Subiendo inventario a la nube..."),
          ],
        ),
      ),
    );

    // Subir archivo
    final uploadTask = storageRef.putFile(localFile);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    print('CSV subido a Firebase Storage: $downloadUrl');

    // 7. Navegar a la pantalla de escaneo
    Navigator.of(context).pop(); // Cerrar diálogo de subida
    
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ConteoEscaneoScreen(
          negociosSeleccionados: widget.negociosSeleccionados,
          csvPath: localPath,
        ),
      ),
    );

  } catch (e) {
    // Manejo de errores
    Navigator.of(context).pop();
    print('Error al generar CSV: $e');
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error al generar el inventario: ${e.toString()}"),
        duration: Duration(seconds: 5),
      ),
    );
  }
}

  Future<void> _cargarConteos() async {
    try {
      final pendientes = await _firestore.collection('conteos')
          .where('estatus', isEqualTo: 'paused')
          .orderBy('fecha', descending: true)
          .get();

      final terminados = await _firestore.collection('conteos')
          .where('estatus', isEqualTo: 'finished')
          .orderBy('fecha', descending: true)
          .get();

      setState(() {
        _conteosPendientes = pendientes.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'fechaFormateada': DateFormat('dd/MM/yyyy HH:mm').format((data['fecha'] as Timestamp).toDate()),
          };
        }).toList();

        _conteosTerminados = terminados.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'fechaFormateada': DateFormat('dd/MM/yyyy HH:mm').format((data['fecha'] as Timestamp).toDate()),
            'ano': DateFormat('yyyy').format((data['fecha'] as Timestamp).toDate()),
          };
        }).toList();

        _loadingConteos = false;
      });
    } catch (e) {
      setState(() {
        _loadingConteos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar conteos: $e')),
      );
    }
  }

  void _mostrarConteosPendientes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const Text(
              'Conteos Pendientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loadingConteos
                  ? const Center(child: CircularProgressIndicator())
                  : _conteosPendientes.isEmpty
                      ? const Center(child: Text('No hay conteos pendientes'))
                      : ListView.builder(
                          itemCount: _conteosPendientes.length,
                          itemBuilder: (context, index) {
                            final conteo = _conteosPendientes[index];
                            return ListTile(
                              leading: const Icon(Icons.pause, color: Colors.orange),
                              title: Text(conteo['nombre'] ?? 'Sin nombre'),
                              subtitle: Text(conteo['fechaFormateada']),
                              onTap: () {
                                // Aquí puedes implementar la lógica para continuar el conteo
                                Navigator.pop(context);
                                _continuarConteo(conteo);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarConteosTerminados() {
    final conteosPorAno = <String, List<Map<String, dynamic>>>{};
    
    for (var conteo in _conteosTerminados) {
      final ano = conteo['ano'] as String;
      conteosPorAno.putIfAbsent(ano, () => []).add(conteo);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const Text(
              'Conteos Terminados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loadingConteos
                  ? const Center(child: CircularProgressIndicator())
                  : _conteosTerminados.isEmpty
                      ? const Center(child: Text('No hay conteos terminados'))
                      : ListView.builder(
                          itemCount: conteosPorAno.length,
                          itemBuilder: (context, index) {
                            final ano = conteosPorAno.keys.elementAt(index);
                            final conteosDelano = conteosPorAno[ano]!;
                            final conteosPorMes = <String, List<Map<String, dynamic>>>{};
                            
                            for (var conteo in conteosDelano) {
                              final mes = conteo['mes'] as String;
                              conteosPorMes.putIfAbsent(mes, () => []).add(conteo);
                            }

                            return ExpansionTile(
                              title: Text('ano $ano'),
                              children: conteosPorMes.entries.map((entry) {
                                return ExpansionTile(
                                  title: Text(entry.key),
                                  children: entry.value.map((conteo) {
                                    return ListTile(
                                      leading: const Icon(Icons.check_circle, color: Colors.green),
                                      title: Text(conteo['nombre'] ?? 'Sin nombre'),
                                      subtitle: Text(conteo['fechaFormateada']),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        onPressed: () => _descargarConteo(conteo),
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _continuarConteo(Map<String, dynamic> conteo) {
    // Implementa la lógica para continuar un conteo pausado
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConteoEscaneoScreen(
          negociosSeleccionados: List<String>.from(conteo['negocios']),
          csvPath: '', // Aquí deberías pasar la ruta del CSV si la guardaste
        ),
      ),
    );
  }

  void _descargarConteo(Map<String, dynamic> conteo) {
    // Implementa la lógica para descargar/ver un conteo terminado
    final url = conteo['url'] as String;
    // Usa algún paquete como url_launcher para abrir el enlace
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Selección de Negocios"),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Selecciona los negocios a contar",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('negocios').snapshots(),
            builder: (context, snapshot) {
              // Estados de carga
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error al cargar negocios: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No hay negocios disponibles"));
              }

              final negocios = snapshot.data!.docs;

              return ListView.builder(
                itemCount: negocios.length,
                itemBuilder: (context, index) {
                  final negocioDoc = negocios[index];
                  final negocioData = negocioDoc.data() as Map<String, dynamic>;
                  final negocioId = negocioDoc.id; // ID del documento
                  
                  // Verificar que el ID no sea nulo o vacío
                  if (negocioId.isEmpty) {
                    return const SizedBox(); // Omitir negocios sin ID válido
                  }

                  final estaSeleccionado = widget.negociosSeleccionados.contains(negocioId);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: 2,
                    child: ListTile(
                      leading: negocioData['logo'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                negocioData['logo'],
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.business),
                              ),
                            )
                          : const Icon(Icons.business, size: 40),
                      title: Text(
                        negocioData['nombreEmpresa'] ?? 'Negocio sin nombre',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'ID: ${negocioId.substring(0, 6)}...', // Muestra parte del ID
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: Switch(
                        value: estaSeleccionado,
                        activeColor: const Color(0xFF39FF14),
                        inactiveTrackColor: Colors.grey[300],
                        onChanged: (bool value) {
                          setState(() {
                            if (value) {
                              // Asegurar que no se duplique
                              if (!widget.negociosSeleccionados.contains(negocioId)) {
                                widget.negociosSeleccionados.add(negocioId);
                              }
                            } else {
                              widget.negociosSeleccionados.remove(negocioId);
                            }
                          });
                          print('Negocios seleccionados: ${widget.negociosSeleccionados}');
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (widget.negociosSeleccionados.contains(negocioId)) {
                            widget.negociosSeleccionados.remove(negocioId);
                          } else {
                            widget.negociosSeleccionados.add(negocioId);
                          }
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Botón de acción
        if (widget.negociosSeleccionados.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.negociosSeleccionados.isEmpty
                    ? null
                    : () {
                        print('Negocios a procesar: ${widget.negociosSeleccionados}');
                        _generarCSV();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Iniciar conteo (${widget.negociosSeleccionados.length})",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
}

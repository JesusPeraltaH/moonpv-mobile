import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:moonpv/conteo/conteoScanner.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class ConteoNegociosScreen extends StatefulWidget {
  List<Map<String, dynamic>> _conteosPendientes = [];
  List<Map<String, dynamic>> _conteosTerminados = [];

  bool _loadingConteos = true;
  bool _showTerminados = false;
  bool _showPendientes = false;

  final List<String> negociosSeleccionados;
  ConteoNegociosScreen({Key? key, required this.negociosSeleccionados})
      : super(key: key);

  @override
  _ConteoNegociosScreenState createState() => _ConteoNegociosScreenState();
}

class _ConteoNegociosScreenState extends State<ConteoNegociosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> negociosSeleccionados = [];
  List<Map<String, dynamic>> _conteosPendientes = [];
  List<Map<String, dynamic>> _conteosTerminados = [];
  bool _loadingConteos = true;
  bool _mostrarSeccionPendientes = false;
  bool _mostrarSeccionTerminados = false;

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
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener el nombre del conteo (si no está definido _nombreArchivo)
      var _nombreArchivo;
      final nombreConteo = _nombreArchivo ??
          'Conteo_${DateFormat('yyyyMMdd').format(DateTime.now())}';

      // 1. Preparar la estructura del CSV con campos extras
      List<List<String>> csvRows = [
        [
          "Nombre Negocio",
          "Código",
          "Artículo",
          "Cantidad en existencia",
          "Cantidad actual",
          "Diferencia",
          "Observaciones",
          "Fecha conteo",
          "Usuario"
        ]
      ];

      // 2. Procesar cada negocio seleccionado
      for (String negocioId in widget.negociosSeleccionados) {
        final negocioDoc =
            await _firestore.collection('negocios').doc(negocioId).get();

        if (!negocioDoc.exists) {
          debugPrint('Negocio con ID $negocioId no encontrado');
          continue;
        }

        final negocioData = negocioDoc.data() as Map<String, dynamic>;
        final nombreEmpresa = negocioData['nombreEmpresa'] ?? 'Sin nombre';

        // Obtener productos del negocio
        final productosSnapshot = await _firestore
            .collection('productos')
            .where('negocioId', isEqualTo: negocioId)
            .get();

        if (productosSnapshot.docs.isEmpty) {
          debugPrint(
              'No se encontraron productos para el negocio $nombreEmpresa');
          continue;
        }

        // 3. Agregar cada producto al CSV con campos extras vacíos
        for (var doc in productosSnapshot.docs) {
          final producto = doc.data();

          if (producto['codigo'] == null ||
              producto['nombre'] == null ||
              producto['cantidad'] == null) {
            debugPrint('Producto con datos incompletos: ${doc.id}');
            continue;
          }

          csvRows.add([
            nombreEmpresa,
            producto['codigo'].toString(),
            producto['nombre'].toString(),
            producto['cantidad'].toString(),
            '0', // Cantidad actual inicializada en 0
            '', // Diferencia vacía
            '', // Observaciones vacías
            '', // Fecha conteo
            '', // Usuario
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'conteo_${nombreConteo.replaceAll(' ', '_')}_$timestamp.csv';
      final localPath = "${directory.path}/$fileName";
      final localFile = File(localPath);
      await localFile.writeAsString(csvContent);
      debugPrint('CSV creado localmente en: $localPath');

      // 6. Subir a Firebase Storage
      final storage = FirebaseStorage.instance;
      final storageRef = storage.ref().child('inventarios/$fileName');

      // Mostrar progreso de subida
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo anterior
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
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
      await storageRef.putFile(localFile);
      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint('CSV subido a Firebase Storage: $downloadUrl');

      // 7. Guardar referencia en Firestore
      await _firestore.collection('conteos').add({
        'nombre': nombreConteo,
        'fecha': FieldValue.serverTimestamp(),
        'url_csv': downloadUrl,
        'estatus': 'in_progress',
        'negocios': widget.negociosSeleccionados,
        'userId': _getCurrentUserId() ?? 'usuario_no_identificado',
      });

      // 8. Navegar a la pantalla de escaneo
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar diálogo de subida

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConteoEscaneoScreen(
            negociosSeleccionados: widget.negociosSeleccionados,
            nombreConteo: nombreConteo,
            csvPath: localPath,
            csvUrl: downloadUrl,
            productosContados: [],
          ),
        ),
      );
    } catch (e) {
      // Manejo de errores
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al generar el inventario: ${e.toString()}"),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Error al generar CSV: $e');
    }
  }

// Función para obtener el ID del usuario actual
  String _getCurrentUserId() {
    // Implementación según tu sistema de autenticación
    // Ejemplo para Firebase Auth:
    try {
      return FirebaseAuth.instance.currentUser?.uid ??
          'usuario_no_identificado';
    } catch (e) {
      debugPrint('Error al obtener usuario: $e');
      return 'usuario_no_identificado';
    }
  }

  Future<void> _cargarConteos() async {
    setState(() => _loadingConteos = true);

    try {
      final pendientes = await _firestore
          .collection('conteos')
          .where('estatus', isEqualTo: 'paused')
          .orderBy('fecha', descending: true)
          .get();

      final terminados = await _firestore
          .collection('conteos')
          .where('estatus', isEqualTo: 'finished')
          .orderBy('fecha', descending: true)
          .get();

      setState(() {
        _conteosPendientes = pendientes.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'fechaFormateada': DateFormat('dd/MM/yyyy HH:mm')
                .format((data['fecha'] as Timestamp).toDate()),
          };
        }).toList();

        _conteosTerminados = terminados.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
            'fechaFormateada': DateFormat('dd/MM/yyyy HH:mm')
                .format((data['fecha'] as Timestamp).toDate()),
            'ano': DateFormat('yyyy')
                .format((data['fecha'] as Timestamp).toDate()),
            'mes': DateFormat('MMMM')
                .format((data['fecha'] as Timestamp).toDate()),
          };
        }).toList();

        _loadingConteos = false;
      });
    } catch (e) {
      setState(() => _loadingConteos = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar conteos: $e')),
      );
    }
  }

  Widget _buildConteosPendientes() {
    if (_loadingConteos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conteosPendientes.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.info, color: Colors.blue),
        title: Text('No hay conteos pendientes'),
      );
    }

    return Column(
      children: [
        ListTile(
          title: const Text('Conteos Pendientes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Icon(_mostrarSeccionPendientes
              ? Icons.expand_less
              : Icons.expand_more),
          onTap: () => setState(
              () => _mostrarSeccionPendientes = !_mostrarSeccionPendientes),
        ),
        if (_mostrarSeccionPendientes) ...[
          const Divider(),
          ..._conteosPendientes
              .map((conteo) => ListTile(
                    leading: const Icon(Icons.pause, color: Colors.orange),
                    title: Text(conteo['nombre'] ?? 'Sin nombre'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(conteo['fechaFormateada']),
                        Text(
                          '${conteo['productos_contados'] ?? 0} productos contados',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    onTap: () => _mostrarDialogoContinuarConteo(conteo),
                  ))
              .toList(),
        ],
      ],
    );
  }

  Future<void> _mostrarDialogoContinuarConteo(
      Map<String, dynamic> conteo) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continuar conteo'),
        content: Text(
            '¿Deseas continuar el conteo "${conteo['nombre']}" iniciado el ${conteo['fechaFormateada']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      await _continuarConteo(conteo);
    }
  }

  Future<void> _continuarConteo(Map<String, dynamic> conteo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final datosConteo =
          await _cargarConteoPausado(conteo['id'] ?? conteo['id_temporal']);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      if (datosConteo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el conteo pausado')),
        );
        return;
      }

      // Navegar a la pantalla de conteo con los datos cargados
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConteoEscaneoScreen(
            negociosSeleccionados: datosConteo['negocios'],
            nombreConteo: datosConteo['nombre'],
            productosContados: datosConteo['productos'],
            conteoPausadoId: conteo['id'],
            csvUrl: conteo['url_csv'], csvPath: '', // Pasamos la URL del CSV
          ),
        ),
      );

      // Actualizar lista de conteos al regresar
      _cargarConteos();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al continuar conteo: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _cargarConteoPausado(String docId) async {
    try {
      final doc = await _firestore.collection('conteos').doc(docId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['estatus'] != 'paused') return null;

      // Descargar CSV
      final storage = FirebaseStorage.instance;
      final csvUrl = data['url_csv'] as String;
      final ref = storage.refFromURL(csvUrl);
      final file = File(
          '${(await getTemporaryDirectory()).path}/conteo_pausado_$docId.csv');
      await ref.writeToFile(file);

      // Leer CSV
      final csvString = await file.readAsString();
      final csvTable = const CsvToListConverter().convert(csvString);

      // Convertir a lista de productos (omitir encabezado)
      final productosContados = csvTable
          .skip(1)
          .map((row) => {
                'nombreEmpresa': row[0],
                'codigo': row[1],
                'articulo': row[2],
                'cantidadExistente': row[3],
                'cantidadActual': row[4],
              })
          .toList();

      return {
        'datos': data,
        'productos': productosContados,
        'nombre': data['nombre'],
        'negocios': List<String>.from(data['negocios']),
      };
    } catch (e) {
      debugPrint('Error al cargar conteo pausado: $e');
      return null;
    }
  }

  Widget _buildConteosTerminados() {
    if (_loadingConteos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conteosTerminados.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.info, color: Colors.blue),
        title: Text('No hay conteos terminados'),
      );
    }

    final conteosPorAno = <String, List<Map<String, dynamic>>>{};
    for (var conteo in _conteosTerminados) {
      final ano = conteo['ano'] as String;
      conteosPorAno.putIfAbsent(ano, () => []).add(conteo);
    }

    return Column(
      children: [
        ListTile(
          title: const Text('Conteos Terminados',
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Icon(_mostrarSeccionTerminados
              ? Icons.expand_less
              : Icons.expand_more),
          onTap: () => setState(
              () => _mostrarSeccionTerminados = !_mostrarSeccionTerminados),
        ),
        if (_mostrarSeccionTerminados) ...[
          const Divider(),
          ...conteosPorAno.entries.map((entry) {
            final ano = entry.key;
            final conteosDelAno = entry.value;
            final conteosPorMes = <String, List<Map<String, dynamic>>>{};

            for (var conteo in conteosDelAno) {
              final mes = conteo['mes'] as String;
              conteosPorMes.putIfAbsent(mes, () => []).add(conteo);
            }

            return ExpansionTile(
              title: Text('Año $ano'),
              children: conteosPorMes.entries.map((mesEntry) {
                return ExpansionTile(
                  title: Text(mesEntry.key),
                  children: mesEntry.value.map((conteo) {
                    return ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
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
          }).toList(),
        ],
      ],
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección de Conteos
            Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(8),
                  child: _buildConteosPendientes(),
                ),
                Card(
                  margin: const EdgeInsets.all(8),
                  child: _buildConteosTerminados(),
                ),
              ],
            ),

            // Separador
            const Divider(height: 1, thickness: 2),

            // Sección de Selección de Negocios
            Column(
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
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('negocios').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text("No hay negocios disponibles"));
                    }

                    final negocios = snapshot.data!.docs;
                    return Column(
                      children: negocios.map((negocio) {
                        final data = negocio.data() as Map<String, dynamic>;
                        final estaSeleccionado =
                            widget.negociosSeleccionados.contains(negocio.id);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: data['logo'] != null
                                ? Image.network(data['logo'],
                                    width: 50, height: 50,
                                    errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/moon_negro.png',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    );
                                  })
                                : Image.asset(
                                    'assets/images/moon_negro.png',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                            title: Text(
                                data['nombreEmpresa'] ?? 'Negocio sin nombre'),
                            trailing: Switch(
                              value: estaSeleccionado,
                              onChanged: (value) {
                                setState(() {
                                  if (value) {
                                    widget.negociosSeleccionados
                                        .add(negocio.id);
                                  } else {
                                    widget.negociosSeleccionados
                                        .remove(negocio.id);
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),

            // Botón de acción
            if (widget.negociosSeleccionados.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _generarCSV,
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

            // Espacio adicional al final para evitar que el botón quede pegado al borde
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

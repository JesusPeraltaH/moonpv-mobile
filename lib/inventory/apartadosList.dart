import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApartadosListScreen extends StatefulWidget {
  @override
  _ApartadosListScreenState createState() => _ApartadosListScreenState();
}

class _ApartadosListScreenState extends State<ApartadosListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apartados'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('apartados')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar los apartados'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No hay apartados registrados'));
          }

          final apartados = snapshot.data!.docs;
          final apartadosPendientes = apartados.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['estado'] != 'pagado';
          }).toList();

          final apartadosPagados = apartados.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['estado'] == 'pagado';
          }).toList();

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Sección de apartados pendientes
              Text(
                'Apartados Pendientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 16),
              if (apartadosPendientes.isEmpty)
                Center(
                  child: Text(
                    'No hay apartados pendientes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
              else
                ...apartadosPendientes.map((doc) {
                  final apartado = doc.data() as Map<String, dynamic>;
                  final fecha = (apartado['fecha'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final precioProducto = apartado['precioProducto'] ?? 0.0;
                  final anticipo = apartado['anticipo'] ?? 0.0;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('apartados')
                        .doc(doc.id)
                        .snapshots(),
                    builder: (context, apartadoSnapshot) {
                      if (!apartadoSnapshot.hasData) return SizedBox.shrink();

                      final apartadoData =
                          apartadoSnapshot.data!.data() as Map<String, dynamic>;
                      final abonos =
                          apartadoData['abonos'] as List<dynamic>? ?? [];

                      double totalAbonos = anticipo;
                      for (var abono in abonos) {
                        totalAbonos += (abono['cantidad'] as num).toDouble();
                      }

                      final pendiente = precioProducto - totalAbonos;

                      // Actualizar el estado si está pagado
                      if (pendiente == 0 &&
                          apartadoData['estado'] != 'pagado') {
                        _firestore
                            .collection('apartados')
                            .doc(doc.id)
                            .update({'estado': 'pagado'});
                      }

                      return FutureBuilder(
                        future: _getProductDetails(apartado['productoId']),
                        builder: (context, productSnapshot) {
                          if (!productSnapshot.hasData) {
                            return SizedBox.shrink();
                          }

                          final productDetails =
                              productSnapshot.data as Map<String, String>;

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _showPaymentHistoryDialog(
                                  context, apartado, doc.id),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${fecha.day}/${fecha.month}/${fecha.year}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Pendiente: \$${pendiente.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: pendiente > 0
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      productDetails['productName'] ??
                                          'Producto no encontrado',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Cliente: ${apartado['nombreCliente']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Precio: \$${precioProducto.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          'Anticipo: \$${anticipo.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),

              SizedBox(height: 32),
              // Sección de apartados pagados
              Text(
                'Apartados Pagados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 16),
              if (apartadosPagados.isEmpty)
                Center(
                  child: Text(
                    'No hay apartados pagados',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
              else
                ...apartadosPagados.map((doc) {
                  final apartado = doc.data() as Map<String, dynamic>;
                  final fecha = (apartado['fecha'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final precioProducto = apartado['precioProducto'] ?? 0.0;

                  return FutureBuilder(
                    future: _getProductDetails(apartado['productoId']),
                    builder: (context, productSnapshot) {
                      if (!productSnapshot.hasData) {
                        return SizedBox.shrink();
                      }

                      final productDetails =
                          productSnapshot.data as Map<String, String>;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _showPaymentHistoryDialog(
                              context, apartado, doc.id),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productDetails['productName'] ??
                                            'Producto no encontrado',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Cliente: ${apartado['nombreCliente']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${precioProducto.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '${fecha.day}/${fecha.month}/${fecha.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateApartadoBottomSheet(context),
        label: Text('Crear Apartado'),
        icon: Icon(Icons.add),
      ),
    );
  }

  void _showCreateApartadoBottomSheet(BuildContext context) {
    String? selectedBusinessId;
    String? selectedProductId;
    String? selectedProductName;
    String? selectedProductPrice;
    int? currentProductQuantity;
    final TextEditingController customerNameController =
        TextEditingController();
    final TextEditingController advanceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuevo Apartado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  // Combobox de Negocios
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('negocios').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return CircularProgressIndicator();
                      }

                      final businesses = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Negocio',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedBusinessId,
                        items: businesses.map((business) {
                          final data = business.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: business.id,
                            child: Text(data['nombreEmpresa'] ?? 'Sin nombre'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBusinessId = value;
                            selectedProductId = null;
                            selectedProductName = null;
                            selectedProductPrice = null;
                            currentProductQuantity = null;
                          });
                        },
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // Combobox de Productos
                  if (selectedBusinessId != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('productos')
                          .where('negocioId', isEqualTo: selectedBusinessId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return CircularProgressIndicator();
                        }

                        final products = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Producto',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedProductId,
                          items: products.map((product) {
                            final data = product.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: product.id,
                              child: Text(data['nombre'] ?? 'Sin nombre'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              final product =
                                  products.firstWhere((p) => p.id == value);
                              final data =
                                  product.data() as Map<String, dynamic>;
                              setState(() {
                                selectedProductId = value;
                                selectedProductName = data['nombre'];
                                selectedProductPrice =
                                    data['precio']?.toString() ?? '0';
                                currentProductQuantity = data['cantidad'] ?? 0;
                              });
                            }
                          },
                        );
                      },
                    ),
                  SizedBox(height: 16),
                  // Información del Producto
                  if (selectedProductName != null) ...[
                    Text(
                      'Producto: $selectedProductName',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Precio: \$${selectedProductPrice ?? '0'}',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cantidad disponible: ${currentProductQuantity ?? 0}',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                  ],
                  // Campo para el nombre del cliente
                  TextField(
                    controller: customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Campo para el anticipo
                  TextField(
                    controller: advanceController,
                    decoration: InputDecoration(
                      labelText: 'Anticipo',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedBusinessId == null ||
                          selectedProductId == null ||
                          customerNameController.text.isEmpty ||
                          advanceController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Por favor complete todos los campos requeridos')),
                        );
                        return;
                      }

                      final double advance =
                          double.tryParse(advanceController.text) ?? 0;
                      final double productPrice =
                          double.tryParse(selectedProductPrice ?? '0') ?? 0;

                      if (advance <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('El anticipo debe ser mayor a 0')),
                        );
                        return;
                      }

                      if (advance >= productPrice) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'El anticipo no puede ser mayor o igual al precio del producto')),
                        );
                        return;
                      }

                      try {
                        await _firestore.collection('apartados').add({
                          'negocioId': selectedBusinessId,
                          'productoId': selectedProductId,
                          'nombreCliente': customerNameController.text,
                          'anticipo': advance,
                          'precioProducto': productPrice,
                          'fecha': FieldValue.serverTimestamp(),
                          'estado': 'pendiente',
                          'abonos': [],
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Apartado creado exitosamente')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error al crear el apartado: $e')),
                        );
                      }
                    },
                    child: Text('Crear Apartado'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _getProductDetails(String? productoId) async {
    try {
      String productName = 'Producto no encontrado';

      if (productoId != null && productoId.isNotEmpty) {
        final productDoc =
            await _firestore.collection('productos').doc(productoId).get();
        if (productDoc.exists) {
          final data = productDoc.data();
          if (data != null && data.containsKey('nombre')) {
            productName = data['nombre'];
          }
        }
      }

      return {
        'productName': productName,
      };
    } catch (e) {
      print('Error obteniendo detalles del producto: $e');
      return {
        'productName': 'Error al cargar',
      };
    }
  }

  void _showPaymentHistoryDialog(
      BuildContext context, Map<String, dynamic> apartado, String apartadoId) {
    final precioProducto = apartado['precioProducto'] ?? 0.0;
    final anticipo = apartado['anticipo'] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('apartados').doc(apartadoId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return SizedBox.shrink();

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final abonos = data['abonos'] as List<dynamic>? ?? [];

          // Calcular el total de abonos (incluyendo el anticipo inicial)
          double totalAbonos = anticipo;
          for (var abono in abonos) {
            totalAbonos += (abono['cantidad'] as num).toDouble();
          }

          final pendiente = precioProducto - totalAbonos;

          return Dialog(
            child: Container(
              padding: EdgeInsets.all(20),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de Abonos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      // Total y Restante
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${precioProducto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Restante:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  pendiente > 0 ? Colors.red : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '\$${pendiente.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  pendiente > 0 ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Línea divisoria
                      Divider(),
                      SizedBox(height: 10),
                      // Historial de abonos
                      Text(
                        'Abonos:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Anticipo inicial
                      Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anticipo inicial',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  '${(apartado['fecha'] as Timestamp?)?.toDate().day ?? ''}/${(apartado['fecha'] as Timestamp?)?.toDate().month ?? ''}/${(apartado['fecha'] as Timestamp?)?.toDate().year ?? ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '-\$${anticipo.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      // Abonos adicionales
                      Column(
                        children: abonos.map((abono) {
                          final fecha = DateTime.fromMillisecondsSinceEpoch(
                              abono['fecha'] as int);
                          final cantidad = abono['cantidad'] as double;
                          return Padding(
                            padding: EdgeInsets.only(left: 20, top: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Abono',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      '${fecha.day}/${fecha.month}/${fecha.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '-\$${cantidad.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 10),
                      // Línea divisoria
                      Divider(),
                      SizedBox(height: 20),
                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (pendiente > 0)
                            TextButton(
                              onPressed: () => _showAddPaymentDialog(
                                  context, apartadoId, pendiente),
                              child: Text('Agregar Abono'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                              ),
                            ),
                          if (pendiente > 0) SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cerrar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (pendiente == 0)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(150, 255, 255, 255),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'PAGADO',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPaymentDialog(
      BuildContext context, String apartadoId, double pendiente) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar Abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Monto restante: \$${pendiente.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;

              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('La cantidad debe ser mayor a 0')),
                );
                return;
              }

              if (amount > pendiente) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'La cantidad no puede ser mayor al monto restante')),
                );
                return;
              }

              try {
                await _firestore
                    .collection('apartados')
                    .doc(apartadoId)
                    .update({
                  'abonos': FieldValue.arrayUnion([
                    {
                      'cantidad': amount,
                      'fecha': DateTime.now().millisecondsSinceEpoch,
                    }
                  ]),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abono registrado exitosamente')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al registrar el abono: $e')),
                );
              }
            },
            child: Text('Guardar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

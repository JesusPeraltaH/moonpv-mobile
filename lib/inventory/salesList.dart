import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class SalesListScreen extends StatefulWidget {
  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey();
  bool _isSummaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Ventas'),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('sales')
                .orderBy('fecha', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child:
                        Text('Error al cargar las ventas: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No hay ventas registradas'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('gastos')
                    .orderBy('fecha', descending: false)
                    .snapshots(),
                builder: (context, expensesSnapshot) {
                  if (expensesSnapshot.hasError) {
                    return Center(
                        child: Text(
                            'Error al cargar los gastos: ${expensesSnapshot.error}'));
                  }

                  // Combinar ventas y gastos
                  List<Map<String, dynamic>> allTransactions = [];

                  // Agregar ventas
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    allTransactions.add({
                      ...data,
                      'id': doc.id,
                      'type': 'sale',
                    });
                  }

                  // Agregar gastos
                  if (expensesSnapshot.hasData) {
                    for (var doc in expensesSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      allTransactions.add({
                        ...data,
                        'id': doc.id,
                        'type': 'expense',
                      });
                    }
                  }

                  // Ordenar por fecha
                  allTransactions.sort((a, b) {
                    final aDate =
                        (a['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final bDate =
                        (b['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return aDate.compareTo(bDate);
                  });

                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('ingresos')
                        .orderBy('fecha', descending: false)
                        .snapshots(),
                    builder: (context, incomeSnapshot) {
                      if (incomeSnapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error al cargar los ingresos: ${incomeSnapshot.error}'));
                      }

                      // Combinar ventas, gastos e ingresos
                      List<Map<String, dynamic>> allTransactions = [];

                      // Agregar ventas
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        allTransactions.add({
                          ...data,
                          'id': doc.id,
                          'type': 'sale',
                        });
                      }

                      // Agregar gastos
                      if (expensesSnapshot.hasData) {
                        for (var doc in expensesSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          allTransactions.add({
                            ...data,
                            'id': doc.id,
                            'type': 'expense',
                          });
                        }
                      }

                      // Agregar ingresos
                      if (incomeSnapshot.hasData) {
                        for (var doc in incomeSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          allTransactions.add({
                            ...data,
                            'id': doc.id,
                            'type': 'income',
                          });
                        }
                      }

                      // Ordenar por fecha
                      allTransactions.sort((a, b) {
                        final aDate = (a['fecha'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final bDate = (b['fecha'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        return aDate.compareTo(bDate);
                      });

                      return ListView.builder(
                        itemCount: allTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = allTransactions[index];
                          final fecha =
                              (transaction['fecha'] as Timestamp?)?.toDate() ??
                                  DateTime.now();
                          final isExpense = transaction['type'] == 'expense';
                          final isIncome = transaction['type'] == 'income';

                          if (isIncome) {
                            return Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              color: Colors.yellow.shade50,
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                title: Text(
                                  transaction['descripcion'] ??
                                      'Sin descripción',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${fecha.day}/${fecha.month}/${fecha.year} - ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '\$${(transaction['monto'] ?? 0).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.add_circle,
                                  size: 16,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            );
                          }

                          return FutureBuilder(
                            future: isExpense
                                ? _getExpenseDetails(transaction['negocioId'],
                                    transaction['productoId'])
                                : _getSaleDetails(
                                    transaction['productos'][0]['negocioId'],
                                    transaction['productos'][0]['productoId']),
                            builder: (context, detailsSnapshot) {
                              if (detailsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox.shrink();
                              }

                              if (detailsSnapshot.hasError ||
                                  !detailsSnapshot.hasData) {
                                return SizedBox.shrink();
                              }

                              final details =
                                  detailsSnapshot.data as Map<String, String>;

                              if (details['businessName'] ==
                                  'Negocio no encontrado') {
                                return SizedBox.shrink();
                              }

                              return Card(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                color: isExpense ? Colors.red.shade50 : null,
                                child: ListTile(
                                  contentPadding: EdgeInsets.all(16),
                                  title: Text(
                                    isExpense
                                        ? details['productName'] ??
                                            'Producto desconocido'
                                        : details['productName'] ??
                                            'Producto desconocido',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isExpense
                                          ? Colors.red.shade900
                                          : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 4),
                                      Text(
                                        details['businessName']!,
                                        style: TextStyle(
                                          color: isExpense
                                              ? Colors.red.shade700
                                              : null,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${fecha.day}/${fecha.month}/${fecha.year} - ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            isExpense
                                                ? '-\$${((transaction['cantidad'] ?? 0) * (transaction['precioUnitario'] ?? 0)).toStringAsFixed(2)}'
                                                : 'Total: \$${(transaction['productos'][0]['precioVenta'] ?? 0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: isExpense
                                                  ? Colors.red.shade900
                                                  : Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    isExpense
                                        ? Icons.remove_circle
                                        : Icons.arrow_forward_ios,
                                    size: 16,
                                    color:
                                        isExpense ? Colors.red.shade900 : null,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          Positioned(
            left: 16,
            bottom: 40,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('sales')
                  .where('fecha',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                        DateTime.now().subtract(Duration(days: 7)),
                      ))
                  .snapshots(),
              builder: (context, salesSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('gastos')
                      .where('fecha',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(
                            DateTime.now().subtract(Duration(days: 7)),
                          ))
                      .snapshots(),
                  builder: (context, expensesSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('ingresos')
                          .where('fecha',
                              isGreaterThanOrEqualTo: Timestamp.fromDate(
                                DateTime.now().subtract(Duration(days: 7)),
                              ))
                          .snapshots(),
                      builder: (context, incomeSnapshot) {
                        double totalSales = 0;
                        double totalExpenses = 0;
                        double totalIncome = 0;

                        if (salesSnapshot.hasData) {
                          for (var doc in salesSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            if (data['productos'] != null &&
                                (data['productos'] as List).isNotEmpty) {
                              totalSales +=
                                  (data['productos'][0]['precioVenta'] ?? 0)
                                      .toDouble();
                            }
                          }
                        }

                        if (expensesSnapshot.hasData) {
                          for (var doc in expensesSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            totalExpenses += ((data['cantidad'] ?? 0) *
                                    (data['precioUnitario'] ?? 0))
                                .toDouble();
                          }
                        }

                        if (incomeSnapshot.hasData) {
                          for (var doc in incomeSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            totalIncome += (data['monto'] ?? 0).toDouble();
                          }
                        }

                        final netTotal =
                            totalSales + totalIncome - totalExpenses;

                        return StatefulBuilder(
                          builder: (context, setState) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSummaryExpanded = !_isSummaryExpanded;
                                });
                              },
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Última Semana',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Total: ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(
                                          '\$${netTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: netTotal >= 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          _isSummaryExpanded
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: Colors.amber[900],
                                        ),
                                      ],
                                    ),
                                    if (_isSummaryExpanded) ...[
                                      SizedBox(height: 8),
                                      Text(
                                        'Ventas: \$${totalSales.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'Ingresos: \$${totalIncome.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[900],
                                        ),
                                      ),
                                      Text(
                                        'Gastos: \$${totalExpenses.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.money_off),
                    title: Text('Registrar Gasto'),
                    onTap: () {
                      Navigator.pop(context);
                      _showExpenseBottomSheet(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.attach_money),
                    title: Text('Registrar Ingreso'),
                    onTap: () {
                      Navigator.pop(context);
                      _showIncomeBottomSheet(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      backgroundColor: Colors.blue,
      elevation: 4,
    );
  }

  void _showExpenseBottomSheet(BuildContext context) {
    String? selectedBusinessId;
    String? selectedProductId;
    String? selectedProductName;
    String? selectedProductPrice;
    int? currentProductQuantity;
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

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
                    'Nuevo Gasto',
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
                  // Fila de Código Manual y Cámara
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Código Manual',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.camera_alt),
                        onPressed: () {
                          // TODO: Implementar funcionalidad de cámara
                        },
                      ),
                    ],
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
                      'Cantidad actual: ${currentProductQuantity ?? 0}',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: 'Cantidad a descontar',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Razón (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedBusinessId == null ||
                          selectedProductId == null ||
                          quantityController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Por favor complete todos los campos requeridos')),
                        );
                        return;
                      }

                      final int quantityToSubtract =
                          int.tryParse(quantityController.text) ?? 0;
                      if (quantityToSubtract <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('La cantidad debe ser mayor a 0')),
                        );
                        return;
                      }

                      if (currentProductQuantity != null &&
                          quantityToSubtract > currentProductQuantity!) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'La cantidad a descontar no puede ser mayor a la cantidad actual')),
                        );
                        return;
                      }

                      try {
                        // Crear el registro de gasto
                        await _firestore.collection('gastos').add({
                          'negocioId': selectedBusinessId,
                          'productoId': selectedProductId,
                          'cantidad': quantityToSubtract,
                          'razon': reasonController.text,
                          'fecha': FieldValue.serverTimestamp(),
                          'precioUnitario':
                              double.tryParse(selectedProductPrice ?? '0') ?? 0,
                        });

                        // Actualizar la cantidad del producto
                        await _firestore
                            .collection('productos')
                            .doc(selectedProductId)
                            .update({
                          'cantidad': FieldValue.increment(-quantityToSubtract),
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Gasto registrado exitosamente')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error al registrar el gasto: $e')),
                        );
                      }
                    },
                    child: Text('Guardar Gasto'),
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

  void _showIncomeBottomSheet(BuildContext context) {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuevo Ingreso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Monto',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (descriptionController.text.isEmpty ||
                      amountController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Por favor complete todos los campos')),
                    );
                    return;
                  }

                  try {
                    await _firestore.collection('ingresos').add({
                      'descripcion': descriptionController.text,
                      'monto': double.tryParse(amountController.text) ?? 0,
                      'fecha': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Ingreso registrado exitosamente')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al registrar el ingreso: $e')),
                    );
                  }
                },
                child: Text('Guardar Ingreso'),
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
  }

  Future<Map<String, String>> _getSaleDetails(
      String? negocioId, String? productoId) async {
    try {
      String businessName = 'Negocio no encontrado';
      String productName = 'Producto desconocido';

      if (negocioId != null && negocioId.isNotEmpty) {
        final businessDoc =
            await _firestore.collection('negocios').doc(negocioId).get();

        if (businessDoc.exists) {
          final data = businessDoc.data();
          if (data != null && data.containsKey('nombreEmpresa')) {
            businessName = data['nombreEmpresa'];
          }
        }
      }

      if (businessName != 'Negocio no encontrado' &&
          productoId != null &&
          productoId.isNotEmpty) {
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
        'businessName': businessName,
        'productName': productName,
      };
    } catch (e) {
      print('Error obteniendo detalles: $e');
      return {
        'businessName': 'Negocio no encontrado',
        'productName': 'Error al cargar',
      };
    }
  }

  Future<Map<String, String>> _getExpenseDetails(
      String? negocioId, String? productoId) async {
    try {
      String businessName = 'Negocio no encontrado';
      String productName = 'Producto desconocido';

      if (negocioId != null && negocioId.isNotEmpty) {
        final businessDoc =
            await _firestore.collection('negocios').doc(negocioId).get();

        if (businessDoc.exists) {
          final data = businessDoc.data();
          if (data != null && data.containsKey('nombreEmpresa')) {
            businessName = data['nombreEmpresa'];
          }
        }
      }

      if (businessName != 'Negocio no encontrado' &&
          productoId != null &&
          productoId.isNotEmpty) {
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
        'businessName': businessName,
        'productName': productName,
      };
    } catch (e) {
      print('Error obteniendo detalles del gasto: $e');
      return {
        'businessName': 'Negocio no encontrado',
        'productName': 'Error al cargar',
      };
    }
  }
}

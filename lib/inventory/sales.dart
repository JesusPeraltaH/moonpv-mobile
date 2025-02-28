import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Finanzas de Negocios'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getBusinesses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> businesses = snapshot.data!;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
            ),
            itemCount: businesses.length,
            itemBuilder: (context, index) {
              var business = businesses[index];
              return GestureDetector(
                onTap: () {
                  _showBusinessFinancialDetails(context, business);
                },
                child: Card(
                  margin: EdgeInsets.all(8.0),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          business['nombreEmpresa'],
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.0),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getFinancialData(business['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            if (!snapshot.hasData) {
                              return Text('No hay datos financieros');
                            }

                            var financialData = snapshot.data!;
                            return Column(
                              children: [
                                Text(
                                    'Ventas: \$${financialData['ventas'] ?? '0.00'}'),
                                Text(
                                    'Gastos: \$${financialData['gastos'] ?? '0.00'}'),
                                Text(
                                    'Inversiones: \$${financialData['inversiones'] ?? '0.00'}'),
                                Text(
                                    'Capital: \$${financialData['capital'] ?? '0.00'}'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Obtener negocios desde Firestore
  Stream<List<Map<String, dynamic>>> _getBusinesses() {
    return FirebaseFirestore.instance
        .collection('negocios')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'nombreEmpresa': doc['nombreEmpresa'],
                })
            .toList());
  }

  // Obtener datos financieros de un negocio
  Future<Map<String, dynamic>> _getFinancialData(String businessId) async {
    // Obtener ventas
    var salesSnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('negocioId', isEqualTo: businessId)
        .get();
    double totalSales = salesSnapshot.docs.fold(0.0, (sum, doc) {
      return sum + (doc['total'] as num).toDouble();
    });

    // Obtener gastos
    var expensesSnapshot = await FirebaseFirestore.instance
        .collection('gastos')
        .where('negocioId', isEqualTo: businessId)
        .get();
    double totalExpenses = expensesSnapshot.docs.fold(0.0, (sum, doc) {
      return sum + (doc['monto'] as num).toDouble();
    });

    // Obtener inversiones
    var investmentsSnapshot = await FirebaseFirestore.instance
        .collection('inversiones')
        .where('negocioId', isEqualTo: businessId)
        .get();
    double totalInvestments = investmentsSnapshot.docs.fold(0.0, (sum, doc) {
      return sum + (doc['monto'] as num).toDouble();
    });

    // Calcular capital total
    double capital = totalSales - totalExpenses + totalInvestments;

    return {
      'ventas': totalSales.toStringAsFixed(2),
      'gastos': totalExpenses.toStringAsFixed(2),
      'inversiones': totalInvestments.toStringAsFixed(2),
      'capital': capital.toStringAsFixed(2),
    };
  }

  // Mostrar detalles financieros en un BottomSheet
  void _showBusinessFinancialDetails(
      BuildContext context, Map<String, dynamic> business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getFinancialData(business['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return Center(child: Text('No hay datos financieros'));
            }

            var financialData = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business['nombreEmpresa'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),
                  _buildFinancialDetailItem(
                      'Ventas Totales', financialData['ventas']),
                  _buildFinancialDetailItem(
                      'Gastos Totales', financialData['gastos']),
                  _buildFinancialDetailItem(
                      'Inversiones Totales', financialData['inversiones']),
                  _buildFinancialDetailItem(
                      'Capital Total', financialData['capital']),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      _addExpense(context, business['id']);
                    },
                    child: Text('Agregar Gasto'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _addInvestment(context, business['id']);
                    },
                    child: Text('Agregar Inversión'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Widget para mostrar un detalle financiero
  Widget _buildFinancialDetailItem(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16),
          ),
          Text(
            '\$$value',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Función para agregar un gasto
  void _addExpense(BuildContext context, String businessId) {
    TextEditingController nameController = TextEditingController();
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar Gasto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre del Gasto'),
              ),
              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('gastos').add({
                    'negocioId': businessId,
                    'nombre': nameController.text,
                    'monto': double.parse(amountController.text),
                    'fecha': DateTime.now().toString(),
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // Función para agregar una inversión
  void _addInvestment(BuildContext context, String businessId) {
    TextEditingController nameController = TextEditingController();
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar Inversión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    InputDecoration(labelText: 'Nombre de la Inversión'),
              ),
              TextField(
                controller: amountController,
                decoration: InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    amountController.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('inversiones')
                      .add({
                    'negocioId': businessId,
                    'nombre': nameController.text,
                    'monto': double.parse(amountController.text),
                    'fecha': DateTime.now().toString(),
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

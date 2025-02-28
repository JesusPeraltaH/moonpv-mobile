import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ventas'),
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
              return Card(
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
                      // Aquí puedes agregar la lógica para obtener productos vendidos y total de ventas
                      Text('Productos Vendidos: 0'), // Cambiar a la lógica real
                      Text(
                          'Total de Ventas: \$0.00'), // Cambiar a la lógica real
                    ],
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
}

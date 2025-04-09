import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moonpv/model/sales_report_bottom_sheet.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';


import 'package:shared_preferences/shared_preferences.dart';

class BusinessOwnerScreen extends StatefulWidget {
  @override
  _BusinessOwnerScreenState createState() => _BusinessOwnerScreenState();
}

class _BusinessOwnerScreenState extends State<BusinessOwnerScreen> {
  String businessName = '';
  String businessId = '';
  double totalSales = 0;
  List<Map<String, dynamic>> topProducts = [];
  List<Map<String, dynamic>> outOfStockProducts = [];
  bool isLoading = true;
  List<Map<String, dynamic>> _salesReportData = [];


  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }




Future<void> _selectCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        // Después de seleccionar el rango, actualizamos los datos de ventas
        _fetchSalesData(); // Actualiza los datos de ventas basados en el nuevo rango
      });
    }
  }

  Future<void> _saveAndOpenPdf(Uint8List bytes, String fileName) async {
    try {
      // Obtener directorio temporal
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.pdf');

      // Guardar el archivo
      await file.writeAsBytes(bytes);

      // Abrir el archivo
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el PDF: $e')),
      );
    }
  }

  Future<void> _loadBusinessData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() => businessName = userDoc['business'] ?? 'Mi Negocio');

        final negociosQuery = await FirebaseFirestore.instance
            .collection('negocios')
            .where('nombreEmpresa', isEqualTo: businessName)
            .limit(1)
            .get();

        if (negociosQuery.docs.isNotEmpty) {
          setState(() => businessId = negociosQuery.docs.first.id);
          await _fetchSalesData();
          await _fetchInventoryData();
        }
      }
    } catch (e) {
      print('Error cargando datos: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> _fetchSalesData() async {
    if (businessId.isEmpty) return;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(Duration(days: 30));

    try {
      final salesQuery = await FirebaseFirestore.instance
          .collection('sales')
          .where('fecha', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();

      double total = 0;
      Map<String, double> productCounts = {};
      List<Map<String, dynamic>> allSoldProducts = [];
      Set<String> productIds = Set();

      // Primero recolectamos todos los IDs de productos
      for (var sale in salesQuery.docs) {
        final productos = sale['productos'] as List<dynamic>? ?? [];

        for (var producto in productos) {
          if (producto is Map && producto['negocioId'] == businessId) {
            final productId = producto['productoId']?.toString() ?? '';
            if (productId.isNotEmpty) {
              productIds.add(productId);
            }
          }
        }
      }

      // Obtenemos todos los nombres de productos en una sola consulta
      final productNames = await _getProductNames(productIds.toList());

      // Procesamos las ventas con los nombres ya disponibles
      for (var sale in salesQuery.docs) {
        final productos = sale['productos'] as List<dynamic>? ?? [];
        final saleDate = sale['fecha'].toDate();

        for (var producto in productos) {
          if (producto is Map && producto['negocioId'] == businessId) {
            final productId = producto['productoId']?.toString() ?? '';
            final productName =
                productNames[productId] ?? 'Producto no encontrado';
            final quantity = producto['cantidad'] ?? 0;
            final price = producto['precioVenta'] ?? 0;
            final subtotal = quantity * price;

            allSoldProducts.add({
              'fecha': DateFormat('dd/MM/yyyy').format(saleDate),
              'productoId': productId,
              'nombre': productName,
              'cantidad': quantity,
              'precio': price,
              'subtotal': subtotal,
            });

            total += subtotal;
            productCounts.update(
              productName,
              (value) => value + quantity,
              ifAbsent: () => quantity.toDouble(),
            );
          }
        }
      }

      // Obtener los 5 productos más vendidos
      final sortedProducts = productCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        totalSales = total;
        topProducts = sortedProducts
            .take(5)
            .map((e) => {'nombre': e.key, 'cantidad': e.value.toInt()})
            .toList();
        _salesReportData = allSoldProducts; // Ahora está definido
      });
    } catch (e) {
      print('Error en _fetchSalesData: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos de ventas: $e')),
      );
    }
  }

// Función para obtener múltiples nombres de productos
  Future<Map<String, String>> _getProductNames(List<String> productIds) async {
    final Map<String, String> productNames = {};

    if (productIds.isEmpty) return productNames;

    try {
      // Consultar en lotes de 10 (límite de Firestore para whereIn)
      for (var i = 0; i < productIds.length; i += 10) {
        final batch = productIds.sublist(
            i, i + 10 > productIds.length ? productIds.length : i + 10);

        final query = await FirebaseFirestore.instance
            .collection('productos')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in query.docs) {
          productNames[doc.id] = doc['nombre'] ?? 'Producto sin nombre';
        }
      }
    } catch (e) {
      print('Error al obtener nombres de productos: $e');
    }

    return productNames;
  }

  Future<void> _fetchInventoryData() async {
    if (businessId.isEmpty) return;

    try {
      final inventoryQuery = await FirebaseFirestore.instance
          .collection('productos')
          .where('negocioId', isEqualTo: businessId)
          .where('cantidad', isEqualTo: 0)
          .get();

      setState(() {
        outOfStockProducts = inventoryQuery.docs
            .map((doc) => {
                  'id': doc.id,
                  'nombre': doc['nombre'] ?? 'Producto sin nombre',
                  'cantidad': doc['cantidad'] ?? 0
                })
            .toList();
      });
    } catch (e) {
      print('Error en _fetchInventoryData: $e');
    }
  }

  void _showReportBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SalesReportBottomSheet(
        businessName: businessName,
        businessId: businessId,
        salesData: _salesReportData,
        initialDateRange: DateTimeRange(
          start: DateTime.now().subtract(Duration(days: 30)),
          end: DateTime.now(),
        ),
      ),
    );
  }

 


  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar sesión'),
        content: Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isLoggedIn');
                await prefs.remove('userId');
                Get.offAll(() => LoginScreen());
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cerrar sesión: $e')),
                );
              }
            },
            child: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Panel de Negocio"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bienvenido a",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text(businessName,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  SizedBox(height: 30),

                  // Resumen de ventas (ahora clickeable)
                  GestureDetector(
                    onTap: _showReportBottomSheet,
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text("Resumen de Ventas",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Spacer(),
                                Icon(Icons.arrow_drop_down, size: 24),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text("\$${totalSales.toStringAsFixed(2)}",
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                            SizedBox(height: 5),
                            Text("Toca para generar reportes",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  if (outOfStockProducts.isNotEmpty) ...[
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Productos Agotados",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                            SizedBox(height: 10),
                            ...outOfStockProducts
                                .map((product) => ListTile(
                                      leading: Icon(Icons.warning,
                                          color: Colors.orange),
                                      title: Text(product['nombre']),
                                      subtitle: Text(
                                          "Cantidad: ${product['cantidad']}"),
                                    ))
                                .toList(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Productos Más Vendidos",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          ...topProducts
                              .map((product) => ListTile(
                                    leading:
                                        Icon(Icons.star, color: Colors.amber),
                                    title: Text(product['nombre']),
                                    subtitle: Text(
                                        "Vendidos: ${product['cantidad']}"),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

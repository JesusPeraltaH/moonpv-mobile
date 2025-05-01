import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  String _getMonthName(int month) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas del Mes por Negocio'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getBusinesses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> businesses = snapshot.data!;

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
            ),
            itemCount: businesses.length,
            itemBuilder: (context, index) {
              var business = businesses[index];
              return GestureDetector(
                onTap: () async {
                  // Abre el diálogo de selección de meses
                  final selectedMonths = await _showMonthPickerDialog(context);

                  // Si el usuario seleccionó al menos un mes, muestra el modal con ventas filtradas
                  if (selectedMonths != null && selectedMonths.isNotEmpty) {
                    _loadSalesAndShowModal(context, business, selectedMonths);
                  } else {
                    // Si no se seleccionaron meses, puedes mostrar un mensaje o manejar el caso
                    print("No se seleccionaron meses.");
                  }
                },
                child: Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          business['nombreEmpresa'],
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        FutureBuilder<Map<String, dynamic>>(
                          future:
                              _getSalesCountAndTotalThisMonth(business['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }

                            int salesCount = snapshot.data?['count'] ?? 0;
                            double totalSales = snapshot.data?['total'] ?? 0.0;

                            return Column(
                              children: [
                                Text(
                                  'Ventas: $salesCount',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Total: \$${totalSales.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
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

  DateTime? _parseFechaString(String fecha) {
    try {
      // Ejemplo de fecha que tienes: "9 de abril de 2025, 5:24:18 p.m UTC-7"
      // Solo nos interesa la fecha antes de la coma
      String soloFecha = fecha.split(',')[0];

      List<String> partes = soloFecha.split(' de ');

      int dia = int.parse(partes[0]);
      String mesTexto = partes[1].toLowerCase();
      int anio = int.parse(partes[2]);

      Map<String, int> meses = {
        'enero': 1,
        'febrero': 2,
        'marzo': 3,
        'abril': 4,
        'mayo': 5,
        'junio': 6,
        'julio': 7,
        'agosto': 8,
        'septiembre': 9,
        'octubre': 10,
        'noviembre': 11,
        'diciembre': 12,
      };

      int mes = meses[mesTexto] ?? 1;

      return DateTime(anio, mes, dia);
    } catch (e) {
      print('Error al parsear la fecha: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getSalesCountAndTotalThisMonth(
      String negocioId) async {
    DateTime now = DateTime.now();
    DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);

    int count = 0;
    double total = 0.0;

    try {
      var salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
          .get();

      print('VENTAS ENCONTRADAS PARA NEGOCIO $negocioId:');
      for (var doc in salesSnapshot.docs) {
        print(doc.data());
      }

      for (var doc in salesSnapshot.docs) {
        var productos = List<Map<String, dynamic>>.from(doc['productos']);

        for (var producto in productos) {
          if (producto['negocioId'] == negocioId) {
            // Buscamos el producto para sacar su precio
            var productDoc = await FirebaseFirestore.instance
                .collection('productos')
                .doc(producto['productoId'])
                .get();

            double precioProducto = (productDoc['precio'] as num).toDouble();
            total += precioProducto;
            count++;
          }
        }
      }
    } catch (e) {
      print('Error obteniendo ventas: $e');
    }

    return {
      'count': count,
      'total': total,
    };
  }

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

  Future<int> _getSalesCountThisMonth(String businessId) async {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    var salesSnapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('productos.negocioId', isEqualTo: businessId)
        .where('fecha', isGreaterThanOrEqualTo: startOfMonth)
        .get();

    return salesSnapshot.docs.length;
  }

  Future<DateTime?> _showMonthPicker(
      BuildContext context, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      return DateTime(picked.year, picked.month);
    }
    return null;
  }

  Future<List<DateTime>?> _showMonthPickerDialog(BuildContext context) async {
    final List<DateTime> selectedMonths = [];
    final now = DateTime.now();

    return await showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecciona los meses'),
          content: SingleChildScrollView(
            child: Column(
              children: List.generate(12, (index) {
                final month = DateTime(now.year, index + 1);
                return CheckboxListTile(
                  title: Text(_getMonthName(month.month)),
                  value: selectedMonths.contains(month),
                  onChanged: (bool? selected) {
                    if (selected == true) {
                      selectedMonths.add(month);
                    } else {
                      selectedMonths.remove(month);
                    }
                    (context as Element)
                        .markNeedsBuild(); // Redibujar el widget
                  },
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context, selectedMonths.isNotEmpty ? selectedMonths : null);
              },
              child: Text('Filtrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSalesAndShowModal(BuildContext context,
      Map<String, dynamic> business, List<DateTime> selectedMonths) async {
    List<Map<String, dynamic>> salesData = [];
    double totalVentas = 0.0;

    for (var selectedMonth in selectedMonths) {
      DateTime startOfMonth =
          DateTime(selectedMonth.year, selectedMonth.month, 1);
      DateTime startOfNextMonth =
          DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

      var salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('fecha',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('fecha', isLessThan: Timestamp.fromDate(startOfNextMonth))
          .get();

      for (var doc in salesSnapshot.docs) {
        var productos = List<Map<String, dynamic>>.from(doc['productos']);
        String fechaVenta = '';
        var rawFecha = doc['fecha'];

        if (rawFecha is String) {
          fechaVenta = rawFecha.split(',')[0];
        } else if (rawFecha is Timestamp) {
          DateTime dateTime = rawFecha.toDate();
          fechaVenta =
              '${dateTime.day} de ${_getMonthName(dateTime.month)} de ${dateTime.year}';
        }

        for (var producto in productos) {
          if (producto['negocioId'] == business['id']) {
            var productDoc = await FirebaseFirestore.instance
                .collection('productos')
                .doc(producto['productoId'])
                .get();

            double precioProducto = (productDoc['precio'] as num).toDouble();
            totalVentas += precioProducto;

            salesData.add({
              'fecha': fechaVenta,
              'nombreProducto': productDoc['nombre'],
              'precio': precioProducto,
            });
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              Center(
                child: Text(
                  'Ventas de ${_getMonthName(selectedMonths[0].month)} ${selectedMonths[0].year}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: salesData.isEmpty
                    ? const Center(
                        child: Text('No hay ventas en este mes.'),
                      )
                    : ListView.builder(
                        itemCount: salesData.length,
                        itemBuilder: (context, index) {
                          var sale = salesData[index];
                          return ListTile(
                            title: Text(sale['nombreProducto']),
                            subtitle: Text('Fecha: ${sale['fecha']}'),
                            trailing:
                                Text('\$${sale['precio'].toStringAsFixed(2)}'),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Total de ventas: \$${totalVentas.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _generateAndOpenPdf(
                          business['nombreEmpresa'], salesData, totalVentas);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generar PDF y abrir'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateAndOpenPdf(String businessName,
      List<Map<String, dynamic>> sales, double totalVentas) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Ventas del Mes - $businessName',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table(
                columnWidths: {
                  0: pw.FlexColumnWidth(2), // Fecha (más espacio)
                  1: pw.FlexColumnWidth(3), // Nombre del producto
                  2: pw.FlexColumnWidth(1), // Precio
                },
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Fecha',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Producto',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Precio',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...sales.map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(sale['fecha']),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(sale['nombreProducto']),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child:
                              pw.Text('\$${sale['precio'].toStringAsFixed(2)}'),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total de ventas: \$${totalVentas.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/ventas_$businessName.pdf");
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(file.path);
    } catch (e) {
      print('Error al guardar o abrir el PDF: $e');
    }
  }
}

import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SalesReportBottomSheet extends StatefulWidget {
  final String businessName;
  final String businessId;
  final List<Map<String, dynamic>> salesData;
  final DateTimeRange initialDateRange;

  const SalesReportBottomSheet({
    Key? key,
    required this.businessName,
    required this.businessId,
    required this.salesData,
    required this.initialDateRange,
  }) : super(key: key);

  @override
  _SalesReportBottomSheetState createState() => _SalesReportBottomSheetState();
}

class _SalesReportBottomSheetState extends State<SalesReportBottomSheet> {
  late DateTimeRange _selectedRange;
  bool _isGenerating = false;
  String _selectedFormat = 'PDF';
   late String _selectedPeriod;
  final Map<String, Duration> _predefinedPeriods = {
    'Últimos 7 días': Duration(days: 7),
    'Últimos 14 días': Duration(days: 14),
    'Últimos 30 días': Duration(days: 30),
    'Últimos 60 días': Duration(days: 60),
    'Personalizado': Duration.zero,
  };

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialDateRange;
     _selectedPeriod = 'Personalizado';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleccionar Período:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          ..._buildPeriodOptions(),
          SizedBox(height: 10),
          _buildFormatSelector(),
          SizedBox(height: 10),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Generar Reporte',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }



  List<Widget> _buildPeriodOptions() {
    final format = DateFormat('dd/MM/yyyy');
    return _predefinedPeriods.keys.map((title) {
      return ListTile(
        title: Text(title == 'Personalizado'
            ? 'Personalizado: ${format.format(_selectedRange.start)} - ${format.format(_selectedRange.end)}'
            : title),
        leading: Radio<String>(
          value: title,
          groupValue: _selectedPeriod,
          onChanged: (value) async {
            if (value == 'Personalizado') {
              await _selectCustomRange();
            } else {
              setState(() {
                _selectedPeriod = value!;
                _selectedRange = DateTimeRange(
                  start: DateTime.now().subtract(_predefinedPeriods[value]! ?? Duration.zero),
                  end: DateTime.now(),
                );
              });
            }
          },
        ),
        onTap: () async {
          if (title == 'Personalizado') {
            await _selectCustomRange();
          } else {
            setState(() {
              _selectedPeriod = title;
              _selectedRange = DateTimeRange(
                start: DateTime.now().subtract(_predefinedPeriods[title]! ?? Duration.zero),
                end: DateTime.now(),
              );
            });
          }
        },
      );
    }).toList();
  }


  Widget _buildPeriodOption(String title, Duration duration) {
    return ListTile(
      title: Text(title),
      leading: Radio<DateTimeRange>(
        value: DateTimeRange(
          start: DateTime.now().subtract(duration),
          end: DateTime.now(),
        ),
        groupValue: _selectedRange,
        onChanged: (value) => setState(() => _selectedRange = value!),
      ),
      onTap: () => setState(() {
        _selectedRange = DateTimeRange(
          start: DateTime.now().subtract(duration),
          end: DateTime.now(),
        );
      }),
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Formato de Exportación:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFormatChip('PDF'),
            _buildFormatChip('CSV'),
            _buildFormatChip('Excel'),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatChip(String format) {
    return ChoiceChip(
      label: Text(format),
      selected: _selectedFormat == format,
      onSelected: (selected) => setState(() => _selectedFormat = format),
    );
  }

  Widget _buildGenerateButton() {
  final buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    minimumSize: const Size(double.infinity, 50),
    padding: const EdgeInsets.symmetric(vertical: 12),
  );

  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: buttonStyle,
      onPressed: _isGenerating ? null : _generateReport,
      child: _isGenerating
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Generar y Exportar Reporte',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
    ),
  );
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
        _selectedPeriod = 'Personalizado';
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      // Filtrar datos por el rango seleccionado
      final filteredData = widget.salesData.where((sale) {
        final saleDate = DateFormat('dd/MM/yyyy').parse(sale['fecha']);
        return saleDate
                .isAfter(_selectedRange.start.subtract(Duration(days: 1))) &&
            saleDate.isBefore(_selectedRange.end.add(Duration(days: 1)));
      }).toList();

      if (filteredData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay datos en el período seleccionado')),
        );
        return;
      }

      final fileName =
          'ventas_${DateFormat('yyyyMMdd').format(_selectedRange.start)}_a_${DateFormat('yyyyMMdd').format(_selectedRange.end)}';

      switch (_selectedFormat) {
        case 'PDF':
          await _exportToPDF(filteredData, fileName);
          break;
        case 'CSV':
          await _exportToCSV(filteredData, fileName);
          break;
        case 'Excel':
          await _exportToExcel(filteredData, fileName);
          break;
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar reporte: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportToPDF(
      List<Map<String, dynamic>> data, String fileName) async {
    final pdf = pw.Document();
    final total =
        data.fold<double>(0, (sum, item) => sum + (item['subtotal'] ?? 0));

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(text: 'Reporte de Ventas - ${widget.businessName}'),
              pw.Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_selectedRange.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedRange.end)}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Fecha',
                  'Producto',
                  'Cantidad',
                  'P. Unitario',
                  'Subtotal'
                ],
                data: data
                    .map((sale) => [
                          sale['fecha'],
                          sale['nombre'],
                          sale['cantidad'].toString(),
                          '\$${(sale['precio'] ?? 0).toStringAsFixed(2)}',
                          '\$${(sale['subtotal'] ?? 0).toStringAsFixed(2)}',
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'TOTAL: \$${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _saveAndOpenFile(
        await pdf.save(), '$fileName.pdf', 'application/pdf');
  }

  Future<void> _exportToCSV(
      List<Map<String, dynamic>> data, String fileName) async {
    final csvRows = [
      ['Fecha', 'Producto', 'Cantidad', 'P. Unitario', 'Subtotal'],
      ...data.map((sale) => [
            sale['fecha'],
            sale['nombre'],
            sale['cantidad'].toString(),
            (sale['precio'] ?? 0).toStringAsFixed(2),
            (sale['subtotal'] ?? 0).toStringAsFixed(2),
          ])
    ];

    final csv = const ListToCsvConverter().convert(csvRows);
    await _saveAndOpenFile(utf8.encode(csv), '$fileName.csv', 'text/csv');
  }

  Future<void> _exportToExcel(
      List<Map<String, dynamic>> data, String fileName) async {
    // Implementación básica - en producción usar paquete excel
    await _exportToCSV(data, fileName.replaceAll('.xlsx', '.csv'));
  }

  Future<void> _saveAndOpenFile(
      List<int> bytes, String fileName, String mimeType) async {
    try {
      // Obtener directorio de descargas
      final directory = await getDownloadsDirectory();
      if (directory == null)
        throw Exception('No se pudo acceder al directorio');

      // Guardar archivo
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Abrir archivo
      await OpenFile.open(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte guardado en ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar archivo: $e')),
      );
    }
  }
}

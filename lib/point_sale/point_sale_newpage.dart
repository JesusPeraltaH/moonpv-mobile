import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moonpv/inventory/inventory_page.dart';
import 'package:moonpv/inventory/sales.dart';
import 'package:moonpv/screens/add_user_screen.dart';
import 'package:moonpv/screens/login_screen.dart';
//import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class SalespointNewSalePage extends StatefulWidget {
  final String initialProductCode;

  const SalespointNewSalePage({
    Key? key,
    this.initialProductCode = '',
  }) : super(key: key);

  @override
  _SalespointNewSalePageState createState() => _SalespointNewSalePageState();
}

class _SalespointNewSalePageState extends State<SalespointNewSalePage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final FocusNode _codeFocusNode = FocusNode();
  double conversionRate = 18.50;
  double cambio = 0.00;
  double _changeAmount = 0.00;

  List<Map<String, dynamic>> _saleDetails = [];
  Map<String, dynamic>? _selectedProduct;

  // BlueThermalPrinter printer = BlueThermalPrinter.instance;
  // List<BluetoothDevice> devices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_codeFocusNode);
    });
    _codeController.text = widget.initialProductCode;
    _getDevices(); // Obtener dispositivos Bluetooth al iniciar
  }

  Future<void> _getDevices() async {
    // devices = await printer.getBondedDevices();
  }
  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Get.offAll(
          () => LoginScreen()); // Navega a la pantalla de inicio de sesión
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  void _addProductToSale(Map<String, dynamic> product) async {
    int cantidadAAgregar = int.tryParse(_quantityController.text) ?? 1;
    int cantidadDisponible = await _obtenerCantidadDisponible(product['code']);

    if (cantidadAAgregar > cantidadDisponible) {
      _mostrarAlerta(
          'No hay suficiente inventario disponible. Solo hay $cantidadDisponible unidades disponibles.');
    } else {
      setState(() {
        _saleDetails.add({
          'cantidad': cantidadAAgregar,
          'nombre': product['name'] ?? 'Desconocido',
          'codigo': product['code'] ?? 'Sin código',
          'precio': (product['price'] as num?)?.toDouble() ?? 0.0,
          'total': ((product['price'] as num?)?.toDouble() ?? 0.0) *
              cantidadAAgregar,
        });
        _quantityController.text = '1';
        _codeController.clear();
        FocusScope.of(context).requestFocus(_codeFocusNode);
      });
    }
  }

  Future<int> _obtenerCantidadDisponible(String productCode) async {
    // Lógica para consultar la base de datos y obtener la cantidad disponible
    return 10; // Simulación, reemplaza con la lógica real
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Inventario insuficiente'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  void _finalizarVenta() {
    double grandTotal =
        _saleDetails.fold(0.0, (sum, item) => sum + item['total']);
    String selectedCurrency = 'Pesos';
    double receivedAmount = 0.0;

    // Controladores para manejar los valores de los campos
    TextEditingController cantidadController = TextEditingController();
    TextEditingController cambioPesosController = TextEditingController();
    TextEditingController cambioDolaresController = TextEditingController();

    // Focus node para el campo cantidad
    FocusNode cantidadFocusNode = FocusNode();

    // Función para actualizar los campos de cambio
    void updateChange() {
      double cambioPesos = selectedCurrency == 'Pesos'
          ? receivedAmount - grandTotal
          : receivedAmount * conversionRate - grandTotal;
      double cambioDolares = selectedCurrency == 'Dólares'
          ? receivedAmount - grandTotal / conversionRate
          : receivedAmount / conversionRate - grandTotal / conversionRate;

      cambioPesosController.text = cambioPesos.toStringAsFixed(2);
      cambioDolaresController.text = cambioDolares.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(cantidadFocusNode);
        });

        return AlertDialog(
          title: Text('Finalizar Venta'),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.3,
            height: MediaQuery.of(context).size.height * 0.3,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateDialog) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCurrency,
                              items: ['Pesos', 'Dólares'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              decoration: InputDecoration(labelText: 'Moneda'),
                              onChanged: (String? newValue) {
                                setStateDialog(() {
                                  selectedCurrency = newValue!;
                                  updateChange();
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: TextField(
                              focusNode: cantidadFocusNode,
                              controller: cantidadController,
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setStateDialog(() {
                                  receivedAmount =
                                      double.tryParse(value) ?? 0.0;
                                  updateChange();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Cambio Pesos',
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(color: Colors.red),
                              ),
                              style: TextStyle(color: Colors.red),
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              controller: cambioPesosController,
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Cambio Dólares',
                                border: OutlineInputBorder(),
                                labelStyle: TextStyle(color: Colors.red),
                              ),
                              style: TextStyle(color: Colors.red),
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              controller: cambioDolaresController,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Total Pesos',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              controller: TextEditingController(
                                text: grandTotal.toStringAsFixed(2),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Total Dólares',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              readOnly: true,
                              controller: TextEditingController(
                                text: (grandTotal / conversionRate)
                                    .toStringAsFixed(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                await _guardarVenta(); // Guardar la venta en Firestore
                for (var product in _saleDetails) {
                  if (product['id'] != null) {
                    _actualizarInventario(product['id'], product['cantidad']);
                  } else {
                    print(
                        'El ID del producto es nulo para el producto: ${product['nombre']}');
                  }
                }
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              icon: Icon(Icons.check, color: Colors.white),
              label: Text(
                'Finalizar Venta',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _guardarVenta() async {
    try {
      // Calcular el gran total de la venta
      double grandTotal =
          _saleDetails.fold(0.0, (sum, item) => sum + item['total']);

      // Crear un mapa para almacenar los detalles de la venta
      Map<String, dynamic> venta = {
        'fecha': FieldValue.serverTimestamp(), // Fecha y hora de la venta
        'grandTotal': grandTotal, // Total general de la venta
        'productos': [], // Lista de productos vendidos
      };

      // Recorrer cada producto en _saleDetails
      for (var product in _saleDetails) {
        // Buscar el producto en Firestore para obtener su ID y negocioId
        final querySnapshot = await FirebaseFirestore.instance
            .collection('productos')
            .where('codigo', isEqualTo: product['codigo'])
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final productoFirestore = querySnapshot.docs.first;
          final String productoId = productoFirestore.id;
          final String negocioId = productoFirestore['negocioId'];

          // Agregar los detalles del producto a la venta
          venta['productos'].add({
            'productoId': productoId, // ID del producto
            'negocioId':
                negocioId, // ID del negocio al que pertenece el producto
            'cantidad': product['cantidad'], // Cantidad vendida
            'precioVenta': product['precio'], // Precio al que se vendió
            'total': product['total'], // Total del producto (precio * cantidad)
          });
        } else {
          print('Producto no encontrado en Firestore: ${product['codigo']}');
        }
      }

      // Guardar la venta en Firestore
      await FirebaseFirestore.instance.collection('sales').add(venta);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta guardada correctamente')),
      );

      // Limpiar la lista de productos vendidos
      setState(() {
        _saleDetails.clear();
      });
    } catch (e) {
      // Manejar errores
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la venta: $e')),
      );
    }
  }

  // Método para obtener el negocioId basado en el código del producto
  Future<String?> _getNegocioIdByProductCode(String productCode) async {
    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('productos')
          .where('codigo', isEqualTo: productCode)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first[
            'negocioId']; // Retornar el negocioId del primer documento encontrado
      }
    } catch (e) {
      print('Error al obtener negocioId: $e');
    }
    return null; // Retornar null si no se encuentra el negocioId
  }

  // Método para actualizar el inventario
  Future<void> _actualizarInventario(
      String productCode, int cantidadVendida) async {
    try {
      // Lógica para actualizar la cantidad en el inventario
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(productCode)
          .update({
        'cantidad':
            FieldValue.increment(-cantidadVendida), // Reducir la cantidad
      });
    } catch (e) {
      // Manejo de errores para document not found
      if (e is FirebaseException && e.code == 'not-found') {
        print('El documento con el código $productCode no fue encontrado.');
        // Aquí puedes agregar lógica adicional, como mostrar un mensaje al usuario
      } else {
        print('Error al actualizar el inventario: $e');
      }
    }
  }

  Future<void> _searchProductByCode(String code) async {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, ingresa un código válido')),
      );
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('productos')
          .where('codigo', isEqualTo: code)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final product = querySnapshot.docs.first.data();
        final int requestedQuantity =
            int.tryParse(_quantityController.text) ?? 1;
        final int availableQuantity =
            int.tryParse(product['cantidad']?.toString() ?? '0') ?? 0;

        if (requestedQuantity <= availableQuantity) {
          setState(() {
            // Buscar si el producto ya existe en la lista
            int index = _saleDetails.indexWhere((p) => p['codigo'] == code);

            if (index != -1) {
              // Si el producto ya existe, actualizar la cantidad y el total
              int nuevaCantidad =
                  _saleDetails[index]['cantidad'] + requestedQuantity;
              double nuevoTotal = _saleDetails[index]['precio'] * nuevaCantidad;

              _saleDetails[index]['cantidad'] = nuevaCantidad;
              _saleDetails[index]['total'] = nuevoTotal;
            } else {
              // Si el producto no existe, agregarlo como un nuevo producto
              _saleDetails.add({
                'cantidad': requestedQuantity,
                'nombre': product['nombre'] ?? 'Desconocido',
                'codigo': code,
                'precio': (product['precio'] as num?)?.toDouble() ?? 0.0,
                'total': ((product['precio'] as num?)?.toDouble() ?? 0.0) *
                    requestedQuantity,
              });
            }

            _quantityController.text =
                '1'; // Resetear a 1 después de agregar el producto
            _codeController.clear(); // Limpiar el campo de código
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Producto añadido: ${product['nombre'] ?? 'Desconocido'}')),
          );

          FocusScope.of(context).requestFocus(_codeFocusNode);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'No existe suficiente cantidad de ${product['nombre'] ?? 'Desconocido'} en existencia')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto no encontrado')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al buscar el producto')),
      );
    }
  }

  void _deleteSelectedProduct() {
    if (_selectedProduct != null) {
      setState(() {
        _saleDetails.remove(_selectedProduct);
        _selectedProduct = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto eliminado')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecciona un producto para eliminar')),
      );
    }
  }

  void _cancelSale() {
    setState(() {
      _saleDetails.clear();
      _codeController.clear();
      _quantityController.text = '1'; // Restablecer cantidad a 1
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Venta cancelada y registros limpiados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _saleDetails.fold<int>(
        0, (sum, item) => sum + (item['cantidad'] as int));

    double totalDollars = _saleDetails.fold(
        0.0,
        (sum, item) =>
            sum + (item['precio'] * item['cantidad'] / conversionRate));
    double grandTotal =
        _saleDetails.fold(0.0, (sum, item) => sum + item['total']);

    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: Text('Venta'),
        leading: Builder(builder: (context) {
          return IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        }),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Opciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.inventory),
              title: Text('Inventario'),
              onTap: () {
                Get.to(InventoryPage());
              },
            ),
            ListTile(
              leading: Icon(Icons.sell),
              title: Text('Ventas'),
              onTap: () {
                Get.to(SalesPage());
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Crear Usuarios'),
              onTap: () {
                Get.to(CreateUserScreen());
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configuración'),
              onTap: () {
                // Lógica de navegación
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                _logout(context);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isPortrait) ...[
            // Modo vertical
            Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onSubmitted: (value) {
                      if (_codeController.text.isNotEmpty) {
                        _searchProductByCode(_codeController.text);
                      }
                    },
                  ),
                  SizedBox(height: 16.0),
                  TextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onSubmitted: (value) {
                      if (_codeController.text.isNotEmpty) {
                        _searchProductByCode(_codeController.text);
                      }
                    },
                  ),
                  SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botones más pequeños
                      ElevatedButton.icon(
                        onPressed: _finalizarVenta,
                        icon: Icon(Icons.check, size: 16, color: Colors.white),
                        label: Text(
                          'Finalizar',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 13),
                          backgroundColor: Colors.greenAccent[700],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.print_rounded,
                            size: 16, color: Colors.white),
                        label: Text(
                          'Ticket',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 13),
                          backgroundColor: Colors.blueAccent[200],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _cancelSale,
                        icon: Icon(Icons.close, size: 16, color: Colors.white),
                        label: Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 13),
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    DataTable(
                      columnSpacing: 12.0, // Menor separación entre columnas
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Cantidad')),
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Precio')),
                        DataColumn(label: Text('Total')),
                      ],
                      rows: _saleDetails
                          .map(
                            (product) => DataRow(
                              selected: _selectedProduct == product,
                              onSelectChanged: (selected) {
                                setState(() {
                                  _selectedProduct = selected! ? product : null;
                                });
                              },
                              cells: <DataCell>[
                                DataCell(Text(product['cantidad'].toString())),
                                DataCell(Text(product['nombre'])),
                                DataCell(Text(product['codigo'])),
                                DataCell(Text('\$${product['precio']}')),
                                DataCell(Text('\$${product['total']}')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Textos y botón "Eliminar Producto" alineados hasta abajo
            Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end, // Alinea hasta abajo
                children: [
                  // Textos en horizontal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTotalContainer(
                        title: 'Artículos',
                        value: totalItems.toString(),
                        color: Colors.blue.shade100,
                      ),
                      _buildTotalContainer(
                        title: 'Total \$',
                        value: '\$${totalDollars.toStringAsFixed(2)}',
                        color: Colors.green.shade100,
                      ),
                      _buildTotalContainer(
                        title: 'Gran Total',
                        value: '\$${grandTotal.toStringAsFixed(2)}',
                        color: Colors.red.shade100,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.0),
                  // Botón "Eliminar Producto"
                  ElevatedButton(
                    onPressed: _deleteSelectedProduct,
                    child: Text(
                      'Eliminar Producto',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: Size(double.infinity, 50), // Ancho completo
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Modo horizontal
            Container(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (value) {
                        if (_codeController.text.isNotEmpty) {
                          _searchProductByCode(_codeController.text);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 16.0),
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Código',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (value) {
                        if (_codeController.text.isNotEmpty) {
                          _searchProductByCode(_codeController.text);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 5.0),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _finalizarVenta,
                        icon: Icon(Icons.check, color: Colors.white),
                        label: Text(
                          'Finalizar Venta',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent[700],
                        ),
                      ),
                      SizedBox(height: 5.0),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.print_rounded, color: Colors.white),
                        label: Text(
                          'Ultimo Ticket',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent[200],
                        ),
                      ),
                      SizedBox(height: 5.0),
                      ElevatedButton.icon(
                        onPressed: _cancelSale,
                        icon: Icon(Icons.close, color: Colors.white),
                        label: Text(
                          'Cancelar Venta',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DataTable(
                        columnSpacing: 24.0, // Separación normal entre columnas
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Cantidad')),
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Código')),
                          DataColumn(label: Text('Precio')),
                          DataColumn(label: Text('Total')),
                        ],
                        rows: _saleDetails
                            .map(
                              (product) => DataRow(
                                selected: _selectedProduct == product,
                                onSelectChanged: (selected) {
                                  setState(() {
                                    _selectedProduct =
                                        selected! ? product : null;
                                  });
                                },
                                cells: <DataCell>[
                                  DataCell(
                                      Text(product['cantidad'].toString())),
                                  DataCell(Text(product['nombre'])),
                                  DataCell(Text(product['codigo'])),
                                  DataCell(Text('\$${product['precio']}')),
                                  DataCell(Text('\$${product['total']}')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          _buildTotalContainer(
                            title: 'Artículos',
                            value: totalItems.toString(),
                            color: Colors.blue.shade100,
                          ),
                          SizedBox(height: 12.0),
                          _buildTotalContainer(
                            title: 'Total \$',
                            value: '\$${totalDollars.toStringAsFixed(2)}',
                            color: Colors.green.shade100,
                          ),
                          SizedBox(height: 12.0),
                          _buildTotalContainer(
                            title: 'Gran Total',
                            value: '\$${grandTotal.toStringAsFixed(2)}',
                            color: Colors.red.shade100,
                          ),
                          SizedBox(height: 16.0),
                          ElevatedButton(
                            onPressed: _deleteSelectedProduct,
                            child: Text(
                              'Eliminar Producto',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalContainer({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.0),
          Text(
            value,
            style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

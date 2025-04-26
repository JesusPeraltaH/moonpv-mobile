import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:moonpv/inventory/main_drawer.dart'; // Para formatear la fecha y hora

class AjustesScreen extends StatefulWidget {
  @override
  _AjustesScreenState createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isMultipleAdjust = false;
  List<Map<String, dynamic>> _selectedProducts = [];

  void _searchProductsByCode(String code) async {
    setState(() {
      _searchText = code;
      _isLoading = true;
      _searchResults.clear();
      if (_isMultipleAdjust) {
        _selectedProducts.clear();
      }
    });

    if (code.isNotEmpty) {
      try {
        QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
            .instance
            .collection('productos')
            .where('codigo', isGreaterThanOrEqualTo: code)
            .where('codigo', isLessThan: code + 'z')
            .get();

        setState(() {
          _searchResults = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Agregar el ID del documento
            return data;
          }).toList();
          _isLoading = false;
        });
      } catch (e) {
        print('Error al buscar productos: $e');
        setState(() {
          _isLoading = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar productos.')),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _searchResults.clear();
        if (_isMultipleAdjust) {
          _selectedProducts.clear();
        }
      });
    }
  }

  void _showAdjustProductBottomSheet(Map<String, dynamic> product) {
    TextEditingController _quantityController =
        TextEditingController(text: '0');
    TextEditingController _reasonController = TextEditingController();
    int currentQuantity = product['cantidad'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Producto a Ajustar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Nombre: ${product['nombre'] ?? 'Sin nombre'}'),
                Text('Cantidad en Inventario: $currentQuantity'),
                if (currentQuantity == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '¡Advertencia! Cantidad en inventario es 0.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad a Ajustar',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Razón del Ajuste',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final quantityToAdjust =
                          int.tryParse(_quantityController.text);
                      final reason = _reasonController.text.trim();

                      if (quantityToAdjust != null &&
                          quantityToAdjust >= 0 &&
                          reason.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('ajustes')
                            .add({
                          'datetime': DateTime.now(),
                          'negocioId': product['negocioId'],
                          'producto': {
                            'id': product[
                                'id'], // Aquí también el ID debería estar
                            'codigo': product['codigo'],
                            'nombre': product['nombre'],
                          },
                          'cantidad_ajustada': quantityToAdjust,
                          'razon': reason,
                        });

                        final newQuantity = currentQuantity - quantityToAdjust;

                        await FirebaseFirestore.instance
                            .collection('productos')
                            .doc(product[
                                'id']) // Utiliza el ID para la actualización
                            .update({
                          'cantidad': newQuantity < 0 ? 0 : newQuantity
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Ajuste realizado con éxito.')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Por favor, ingrese una cantidad válida (>= 0) y una razón.')),
                        );
                      }
                    },
                    child: const Text('Guardar Ajuste'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleProductSelection(bool? value, Map<String, dynamic> product) {
    setState(() {
      if (value == true) {
        if (!_selectedProducts.contains(product)) {
          _selectedProducts.add(product);
        }
      } else {
        _selectedProducts.remove(product);
      }
    });
  }

  void _showMultipleAdjustBottomSheet() {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecciona productos para ajustar.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Ajuste Múltiple de Productos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  for (var product in _selectedProducts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${product['nombre'] ?? 'Sin nombre'} (${product['cantidad'] ?? '0'})',
                            ),
                          ),
                          const SizedBox(width: 16),
                          QuantityInput(product: product),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Razón del Ajuste para Todos',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      for (var product in _selectedProducts) {
                        product['adjust_reason'] = value.trim();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        bool isValid = true;
                        for (var product in _selectedProducts) {
                          if (product['adjust_quantity'] == null ||
                              product['adjust_quantity'] < 0 ||
                              product['adjust_reason'] == null ||
                              product['adjust_reason'].isEmpty) {
                            isValid = false;
                            break;
                          }
                        }

                        if (isValid) {
                          for (var product in _selectedProducts) {
                            final quantityToAdjust =
                                product['adjust_quantity'] as int;
                            final reason = product['adjust_reason']
                                as String; // Usar la razón común

                            await FirebaseFirestore.instance
                                .collection('ajustes')
                                .add({
                              'datetime': DateTime.now(),
                              'negocioId': product['negocioId'],
                              'producto': {
                                'id': product['id'],
                                'codigo': product['codigo'],
                                'nombre': product['nombre'],
                              },
                              'cantidad_ajustada': quantityToAdjust,
                              'razon': reason,
                            });

                            final currentQuantity = product['cantidad'] ?? 0;
                            final newQuantity =
                                currentQuantity - quantityToAdjust;

                            await FirebaseFirestore.instance
                                .collection('productos')
                                .doc(product['id'])
                                .update({
                              'cantidad': newQuantity < 0 ? 0 : newQuantity
                            });
                          }

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Ajuste múltiple realizado con éxito.')),
                          );
                          setState(() {
                            _selectedProducts.clear();
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Por favor, ingrese una cantidad (>= 0) y razón válida para todos los productos.')),
                          );
                        }
                      },
                      child: const Text('Guardar Ajuste Múltiple'),
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Productos por Código'),
      ),
      drawer: MainDrawer(
        logoutCallback: (context) {
          print('Cerrando sesión desde AjustesScreen');
        },
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _searchProductsByCode,
              decoration: InputDecoration(
                labelText: 'Buscar por código de producto',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ajuste Múltiple'),
                Switch(
                  value: _isMultipleAdjust,
                  onChanged: (value) {
                    setState(() {
                      _isMultipleAdjust = value;
                      _selectedProducts
                          .clear(); // Limpiar selección al cambiar el modo
                    });
                  },
                ),
              ],
            ),
          ),
          if (_isMultipleAdjust && _searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedProducts.isNotEmpty
                      ? _showMultipleAdjustBottomSheet
                      : null,
                  child: const Text('Ajustar Seleccionados'),
                ),
              ),
            ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 5.0),
                        child: ListTile(
                          title: Text(product['nombre'] ?? 'Sin nombre'),
                          subtitle: Text(
                              'Código: ${product['codigo'] ?? 'Sin código'} - Cantidad: ${product['cantidad'] ?? '0'}'),
                          trailing: _isMultipleAdjust
                              ? Checkbox(
                                  value: _selectedProducts.contains(product),
                                  onChanged: (bool? value) {
                                    _toggleProductSelection(value, product);
                                  },
                                )
                              : null,
                          onTap: _isMultipleAdjust
                              ? () {
                                  _toggleProductSelection(
                                      !_selectedProducts.contains(product),
                                      product);
                                }
                              : () {
                                  _showAdjustProductBottomSheet(product);
                                },
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class QuantityInput extends StatefulWidget {
  final Map<String, dynamic> product;

  const QuantityInput({Key? key, required this.product}) : super(key: key);

  @override
  _QuantityInputState createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  int _quantity = 0;
  TextEditingController _textController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _quantity = widget.product['adjust_quantity'] ?? 0;
    _textController.text = _quantity.toString();
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
      _textController.text = _quantity.toString();
      widget.product['adjust_quantity'] = _quantity;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 0) {
      setState(() {
        _quantity--;
        _textController.text = _quantity.toString();
        widget.product['adjust_quantity'] = _quantity;
      });
    }
  }

  void _onTextChanged(String value) {
    final parsedValue = int.tryParse(value) ?? 0;
    setState(() {
      _quantity = parsedValue;
      widget.product['adjust_quantity'] = _quantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _decrementQuantity,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 40,
          child: TextField(
            controller: _textController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
            ),
            onChanged: _onTextChanged,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _incrementQuantity,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

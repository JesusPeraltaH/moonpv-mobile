import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool showForm = false;
  bool showProductForm = false;
  bool showBusinessProducts =
      false; // Nueva variable para mostrar productos del negocio
  String? selectedBusinessId; // ID del negocio seleccionado
  List<Map<String, dynamic>> productsList =
      []; // Lista de productos del negocio
  bool showProductDetails =
      false; // Para mostrar detalles del producto seleccionado
  Map<String, dynamic>? selectedProduct; // Producto seleccionado
  File? _image;
  final picker = ImagePicker();

  // Controladores para los campos del formulario del negocio
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Controladores para los productos
  List<Map<String, dynamic>> productControllers = [
    {
      'codigo': TextEditingController(),
      'nombre': TextEditingController(),
      'precio': TextEditingController(),
      'cantidad': TextEditingController(),
      'imagen': null,
    },
  ];

  // Lista para almacenar los productos antes de ser guardados
  //List<Map<String, dynamic>> productsList = [];
  int? editingIndex;

  Future<void> _pickImageProducts(int productIndex) async {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Galería'),
                  onTap: () async {
                    final pickedFile =
                        await picker.pickImage(source: ImageSource.gallery);
                    setState(() {
                      if (pickedFile != null) {
                        productControllers[productIndex]['imagen'] =
                            File(pickedFile.path);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Cámara'),
                  onTap: () async {
                    final pickedFile =
                        await picker.pickImage(source: ImageSource.camera);
                    setState(() {
                      if (pickedFile != null) {
                        productControllers[productIndex]['imagen'] =
                            File(pickedFile.path);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  // Cargar la imagen desde la galería o la cámara
  Future<void> _pickImage() async {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Galería'),
                    onTap: () async {
                      final pickedFile =
                          await picker.pickImage(source: ImageSource.gallery);
                      setState(() {
                        if (pickedFile != null) {
                          _image = File(pickedFile.path);
                        }
                      });
                      Navigator.of(context).pop();
                    }),
                ListTile(
                  leading: Icon(Icons.photo_camera),
                  title: Text('Cámara'),
                  onTap: () async {
                    final pickedFile =
                        await picker.pickImage(source: ImageSource.camera);
                    setState(() {
                      if (pickedFile != null) {
                        _image = File(pickedFile.path);
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  Future<bool> _checkIfProductCodeExists(String productCode) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('productos')
        .where('codigo', isEqualTo: productCode)
        .get();

    return query.docs.isNotEmpty;
  }

//  Subir imagen a Firebase Storage
  Future<String?> _uploadImageToFirebase(File image) async {
    try {
      String fileName = 'logos/${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageReference =
          FirebaseStorage.instance.ref().child(fileName);

      // Cargar la imagen
      UploadTask uploadTask = storageReference.putFile(image);
      await uploadTask;

      // Obtener la URL de descarga
      String? downloadUrl = await storageReference.getDownloadURL();
      print('Imagen subida: $downloadUrl'); // Imprimir la URL de la imagen

      return downloadUrl;
    } catch (e) {
      print('Error al subir la imagen: $e'); // Manejar error
      return null;
    }
  }

  // Agregar negocio a Firestore
  Future<void> _addBusiness() async {
    if (_companyNameController.text.isEmpty ||
        _ownerNameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      Get.snackbar('Error', 'Por favor llena todos los campos obligatorios');
      return;
    }

    String? logoUrl;
    if (_image != null) {
      logoUrl = await _uploadImageToFirebase(_image!);
    }

    await FirebaseFirestore.instance.collection('negocios').add({
      'nombreEmpresa': _companyNameController.text,
      'nombreDueno': _ownerNameController.text,
      'telefono': _phoneController.text,
      'logo': logoUrl,
    });

    Get.snackbar('Éxito', 'Negocio agregado correctamente');
    _clearForm();
  }

  // Agregar productos a Firestore
  Future<void> _addProducts(String businessId) async {
    for (var product in productsList) {
      String productCode = product['codigo'];
      String productName = product['nombre'];
      String productPrice = product['precio'];
      String productQuantity = product['cantidad'];
      String? productImageUrl = product['imagen'];

      // Solo subir la imagen si se seleccionó una
      // if (product['imagen'] != null) {
      //   productImageUrl = await _uploadImageToFirebase(File(product[
      //       'imagen'])); // Asegúrate de que 'imagen' sea el path correcto.
      // }
      if (product['imagen'] != null) {
        productImageUrl =
            await _uploadImageToFirebase(File(product['imagen'].path));
      }

      // Verificar si el código de producto ya existe en Firestore
      bool codeExists = await _checkIfProductCodeExists(productCode);
      if (codeExists) {
        Get.snackbar('Error', 'El código de producto $productCode ya existe.');
        return;
      } else {
        List<String> searchKeywords = _generateSearchKeywords(productName);

        await FirebaseFirestore.instance.collection('productos').add({
          'negocioId': businessId,
          'codigo': productCode,
          'nombre': productName,
          'cantidad': productQuantity,
          'precio': double.tryParse(productPrice) ?? 0.0,
          'searchKeywords': searchKeywords,
          'createdAt': FieldValue.serverTimestamp(),
          'sold': false,
          'imagen': productImageUrl, // Guardar la URL de la imagen
        });
      }
    }

    Get.snackbar('Éxito', 'Productos agregados correctamente');
    _clearProductForm();
  }

  List<String> _generateSearchKeywords(String name) {
    List<String> keywords = [];
    List<String> words = name.split(' ');

    for (String word in words) {
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i).toLowerCase());
      }
    }

    for (int i = 0; i < words.length; i++) {
      String subphrase = '';
      for (int j = i; j < words.length; j++) {
        subphrase = subphrase + ' ' + words[j];
        keywords.add(subphrase.trim().toLowerCase());
      }
    }

    return keywords.toSet().toList();
  }

  // Limpiar formulario del negocio
  void _clearForm() {
    setState(() {
      _companyNameController.clear();
      _ownerNameController.clear();
      _phoneController.clear();
      _image = null;
      showForm = false;
    });
  }

  // Limpiar formulario de productos
  void _clearProductForm() {
    setState(() {
      productControllers.clear();
      productsList.clear();
      showProductForm = false;
      editingIndex = null;
      productControllers.add({
        'codigo': TextEditingController(),
        'nombre': TextEditingController(),
        'precio': TextEditingController(),
        'cantidad': TextEditingController(),
        'imagen': null,
      });
    });
  }

  // Guardar producto actual
// Guardar producto actual
  void _saveCurrentProduct() async {
    if (productControllers.isNotEmpty) {
      String productCode = productControllers.last['codigo']!.text;
      String productName = productControllers.last['nombre']!.text;
      String productPrice = productControllers.last['precio']!.text;
      String productQuantity = productControllers.last['cantidad']!.text;

      if (productCode.isNotEmpty &&
          productName.isNotEmpty &&
          productPrice.isNotEmpty &&
          productQuantity.isNotEmpty) {
        // Aquí se guarda la imagen localmente, pero no se sube aún
        String? productImageUrl;
        if (productControllers.last['imagen'] != null) {
          productImageUrl = (productControllers.last['imagen'] as File).path;
        }
        if (editingIndex != null) {
          // Actualizar producto existente
          productsList[editingIndex!] = {
            'codigo': productCode,
            'nombre': productName,
            'precio': productPrice,
            'cantidad': productQuantity,
            'imagen': productImageUrl,
          };
        } else {
          // Agregar nuevo producto
          productsList.add({
            'codigo': productCode,
            'nombre': productName,
            'precio': productPrice,
            'cantidad': productQuantity,
            //'imagen': productImageUrl,
            'imagen': productControllers.last['imagen'],
          });
        }

        setState(() {
          productControllers.removeLast();
          productControllers.add({
            'codigo': TextEditingController(),
            'nombre': TextEditingController(),
            'precio': TextEditingController(),
            'cantidad': TextEditingController(),
            'imagen': null,
          });
          editingIndex = null; // Reiniciar el índice de edición
        });

        print('Lista de productos: $productsList'); // Imprimir aquí
      } else {
        Get.snackbar('Error', 'Completa el formulario antes de continuar');
      }
    }
  }

  void _editProduct(int index) {
    final product = productsList[index];
    productControllers.last['codigo']!.text = product['codigo'];
    productControllers.last['nombre']!.text = product['nombre'];
    productControllers.last['precio']!.text = product['precio'];
    productControllers.last['cantidad']!.text = product['cantidad'];

    // Si hay una imagen, cargarla
    if (product['imagen'] != null) {
      productControllers.last['imagen'] =
          File(product['imagen']); // o la URL si es necesario
    }

    setState(() {
      editingIndex = index; // Guardamos el índice de edición
    });
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
                  'nombreDueno': doc['nombreDueno'],
                  'telefono': doc['telefono'],
                  'logo': doc[
                      'logo'], // Asegúrate de que el logo esté en la base de datos
                })
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventario'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Abrir el Drawer
            },
          ),
        ),
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
                'Menú de Navegación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Página Principal'),
              onTap: () {
                Get.to(SalespointNewSalePage()); // Navegar al home
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (!isPortrait) // Mostrar barra lateral solo en modo horizontal
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showForm = true;
                              showProductForm = false;
                              showBusinessProducts = false;
                            });
                          },
                          child: Text('Agregar Negocio'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showForm = false;
                              showProductForm = true;
                              showBusinessProducts = false;
                            });
                          },
                          child: Text('Agregar Producto'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              showForm = false;
                              showProductForm = false;
                              showBusinessProducts = true;
                            });
                          },
                          child: Text('Ver Negocios'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.grey[200],
                    padding: EdgeInsets.all(16.0),
                    child: showForm
                        ? _buildBusinessForm()
                        : showProductForm
                            ? _buildProductForm()
                            : showBusinessProducts
                                ? _buildBusinessList()
                                : Center(
                                    child: Text(
                                      'Selecciona una opción para continuar',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                  ),
                ),
              ],
            ),
          ),
          if (isPortrait) // Mostrar barra inferior solo en modo vertical
            Container(
              color: Colors.purple,
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.business, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        showForm = true;
                        showProductForm = false;
                        showBusinessProducts = false;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        showForm = false;
                        showProductForm = true;
                        showBusinessProducts = false;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.list, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        showForm = false;
                        showProductForm = false;
                        showBusinessProducts = true;
                      });
                    },
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.home, color: Colors.white), // Botón de Home
                    onPressed: () {
                      Get.to(SalespointNewSalePage()); // Navegar al home
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logo (Opcional)'),
          SizedBox(height: 8.0),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: 150,
              color: Colors.grey[300],
              child: _image == null
                  ? Icon(Icons.add_a_photo, size: 50)
                  : Image.file(_image!, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: _companyNameController,
            decoration: InputDecoration(labelText: 'Nombre del negocio'),
          ),
          TextField(
            controller: _ownerNameController,
            decoration: InputDecoration(labelText: 'Nombre del dueño'),
          ),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: _addBusiness,
            child: Text('Guardar Negocio'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getBusinesses(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return CircularProgressIndicator();
              }

              List<Map<String, dynamic>> businesses = snapshot.data!;

              return DropdownButton<String>(
                value: selectedBusinessId,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedBusinessId = newValue;
                  });
                },
                items: businesses
                    .map((business) => DropdownMenuItem<String>(
                          value: business['id'],
                          child: Text(business['nombreEmpresa']),
                        ))
                    .toList(),
                hint: Text('Seleccionar negocio'),
              );
            },
          ),
          SizedBox(height: 16.0),
          ...productControllers.asMap().entries.map((entry) {
            int index = entry.key;
            var productController = entry.value;
            return Card(
              elevation: 2.0,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: productController['codigo'],
                      decoration: InputDecoration(labelText: 'Código'),
                    ),
                    TextField(
                      controller: productController['nombre'],
                      decoration: InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: productController['precio'],
                      decoration: InputDecoration(labelText: 'Precio'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: productController['cantidad'],
                      decoration: InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                    ),
                    GestureDetector(
                      onTap: () => _pickImageProducts(index),
                      child: Container(
                        height: 100,
                        width: 100,
                        color: Colors.grey[300],
                        child: productController['imagen'] == null
                            ? Icon(Icons.add_a_photo, size: 50)
                            : Image.file(productController['imagen'],
                                fit: BoxFit.cover),
                      ),
                    ),
                    SizedBox(height: 16.0),
                  ],
                ),
              ),
            );
          }).toList(),
          ElevatedButton(
            onPressed: _saveCurrentProduct,
            child: Text(editingIndex == null
                ? 'Agregar otro producto'
                : 'Actualizar producto'),
          ),
          SizedBox(height: 16.0),
          _buildProductTable(),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: () {
              if (selectedBusinessId == null) {
                Get.snackbar('Error', 'Por favor selecciona un negocio');
                return;
              }

              _addProducts(selectedBusinessId!);
            },
            child: Text('Guardar Productos'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTable() {
    return productsList.isEmpty
        ? Text('No hay productos agregados.')
        : DataTable(
            columns: [
              DataColumn(label: Text('C��digo')),
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Precio')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Imagen')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: productsList.map((product) {
              int index = productsList.indexOf(product);
              return DataRow(cells: [
                DataCell(Text(product['codigo'])),
                DataCell(Text(product['nombre'])),
                DataCell(Text(product['precio'])),
                DataCell(Text(product['cantidad'])),
                DataCell(
                  product['imagen'] == null
                      ? Text('Sin imagen')
                      // : Image.file(File(product['imagen']),
                      //   height: 50, width: 50, fit: BoxFit.cover),
                      : Image.network(product['imagen'],
                          height: 50, width: 50, fit: BoxFit.cover),
                ),
                DataCell(
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      _editProduct(index);
                    },
                  ),
                ),
              ]);
            }).toList(),
          );
  }

  // Método para construir la lista de negocios
  Widget _buildBusinessList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        List<Map<String, dynamic>> businesses = snapshot.data!;

        return DataTable(
          columns: [
            DataColumn(label: Text('Logo')),
            DataColumn(label: Text('Nombre Empresa')),
            DataColumn(label: Text('Dueño')),
            DataColumn(label: Text('Teléfono')),
          ],
          rows: businesses.map((business) {
            return DataRow(
                cells: [
                  DataCell(
                    business['logo'] != null
                        ? Image.network(business['logo'],
                            height: 50, width: 50, fit: BoxFit.cover)
                        : Icon(Icons.business,
                            size: 50), // Icono por defecto si no hay logo
                  ),
                  DataCell(Text(business['nombreEmpresa'])),
                  DataCell(Text(business['nombreDueno'])),
                  DataCell(Text(business['telefono'])),
                ],
                onSelectChanged: (selected) {
                  setState(() {
                    selectedBusinessId = business['id'];
                    showBusinessProducts =
                        true; // Mostrar productos del negocio
                    showProductDetails =
                        false; // Reiniciar detalles del producto
                  });
                });
          }).toList(),
        );
      },
    );
  }

  // Método para mostrar los productos del negocio seleccionado
  Widget _buildProductsForBusiness() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProductsForBusiness(selectedBusinessId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<Map<String, dynamic>> products = snapshot.data!;

        return Column(
          children: [
            DataTable(
              columns: [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Precio')),
                DataColumn(label: Text('Cantidad')),
              ],
              rows: products.map((product) {
                return DataRow(
                    cells: [
                      DataCell(Text(product['codigo'])),
                      DataCell(Text(product['nombre'])),
                      DataCell(Text(product['precio'].toString())),
                      DataCell(Text(product['cantidad'].toString())),
                    ],
                    onSelectChanged: (selected) {
                      setState(() {
                        selectedProduct =
                            product; // Guardar el producto seleccionado
                        showProductDetails =
                            true; // Mostrar detalles del producto
                      });
                    });
              }).toList(),
            ),
            if (showProductDetails &&
                selectedProduct != null) // Mostrar detalles del producto
              Container(
                padding: EdgeInsets.all(16.0),
                margin: EdgeInsets.only(top: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey, blurRadius: 4.0, spreadRadius: 2.0),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detalles del Producto',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8.0),
                    Text('Código: ${selectedProduct!['codigo']}'),
                    Text('Nombre: ${selectedProduct!['nombre']}'),
                    Text('Precio: \$${selectedProduct!['precio']}'),
                    Text('Cantidad: ${selectedProduct!['cantidad']}'),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // Método para obtener productos del negocio
  Future<List<Map<String, dynamic>>> _fetchProductsForBusiness(
      String businessId) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('productos')
        .where('negocioId', isEqualTo: businessId)
        .get();

    return query.docs
        .map((doc) => {
              'codigo': doc['codigo'],
              'nombre': doc['nombre'],
              'precio': doc['precio'],
              'cantidad': doc['cantidad'],
            })
        .toList();
  }

  // Método para mostrar el diálogo con productos del negocio
  void _showProductsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Productos del Negocio'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildProductsTable(), // Mostrar tabla de productos
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // Método para construir la tabla de productos
  Widget _buildProductsTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProductsForBusiness(selectedBusinessId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<Map<String, dynamic>> products = snapshot.data!;

        return DataTable(
          columns: [
            DataColumn(label: Text('Código')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Precio')),
            DataColumn(label: Text('Cantidad')),
          ],
          rows: products.map((product) {
            return DataRow(cells: [
              DataCell(Text(product['codigo'])),
              DataCell(Text(product['nombre'])),
              DataCell(Text(product['precio'].toString())),
              DataCell(Text(product['cantidad'].toString())),
            ]);
          }).toList(),
        );
      },
    );
  }
}

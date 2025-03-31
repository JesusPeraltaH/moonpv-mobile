import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/services/barcode_scanner_page.dart';
import 'package:path_provider/path_provider.dart';

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
                  if (pickedFile != null) {
                    // Crear una copia del archivo en caché
                    final File imageFile = File(pickedFile.path);
                    final File cachedImageFile =
                        await _copyFileToCache(imageFile);

                    setState(() {
                      productControllers[productIndex]['imagen'] =
                          cachedImageFile; // Guardar como File
                    });
                  }
                  Navigator.of(context).pop(); // Cerrar el modal
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Cámara'),
                onTap: () async {
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    // Crear una copia del archivo en caché
                    final File imageFile = File(pickedFile.path);
                    final File cachedImageFile =
                        await _copyFileToCache(imageFile);

                    setState(() {
                      productControllers[productIndex]['imagen'] =
                          cachedImageFile; // Guardar como File
                    });
                  }
                  Navigator.of(context).pop(); // Cerrar el modal
                },
              ),
            ],
          ),
        );
      },
    );
  }

// Método para copiar el archivo a la caché
  Future<File> _copyFileToCache(File file) async {
    final Directory cacheDir =
        await getTemporaryDirectory(); // Obtener el directorio temporal
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final String cachedFilePath = '${cacheDir.path}/$fileName';

    return file.copy(cachedFilePath); // Copiar el archivo a la caché
  }

  Future<List<Map<String, dynamic>>> _fetchProductsForBusiness(
      String businessId) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('productos')
        .where('negocioId', isEqualTo: businessId)
        .get();

    return query.docs.map((doc) {
      return {
        'id': doc.id, // ID del producto
        'codigo': doc['codigo'],
        'nombre': doc['nombre'],
        'precio': doc['precio'],
        'cantidad': doc['cantidad'],
        'imagen': doc['imagen'],
      };
    }).toList();
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
      String fileName =
          'productos/${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageReference =
          FirebaseStorage.instance.ref().child(fileName);

      // Subir la imagen
      UploadTask uploadTask = storageReference.putFile(image);
      await uploadTask;

      // Obtener la URL de descarga
      String downloadUrl = await storageReference.getDownloadURL();
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
      if (logoUrl == null) {
        Get.snackbar('Error', 'No se pudo subir la imagen');
        return;
      }
    } else {
      logoUrl =
          'https://ejemplo.com/imagen_predeterminada.png'; // URL de imagen predeterminada
    }

    await FirebaseFirestore.instance.collection('negocios').add({
      'nombreEmpresa': _companyNameController.text,
      'nombreDueno': _ownerNameController.text,
      'telefono': _phoneController.text,
      'logo': logoUrl, // URL de la imagen o imagen predeterminada
    });

    Get.snackbar('Éxito', 'Negocio agregado correctamente');
    _clearForm();
  }

  // Agregar productos a Firestore

  Future<void> _addProducts(String businessId) async {
    try {
      print('Iniciando proceso de guardado de productos...');

      print('Lista de productos antes de guardar: ${productsList.length}');
      print('Contenido de productsList: $productsList');
      for (var i = 0; i < productsList.length; i++) {
        print('Producto $i: ${productsList[i]}');
      }

      for (var product in productsList) {
        String productCode = product['codigo'];
        String productName = product['nombre'];
        String productPrice = product['precio'];
        String productQuantity = product['cantidad'];
        String? productImageUrl;

        // Validar que los campos no estén vacíos
        print('Validando producto:');
        print('Código: $productCode');
        print('Nombre: $productName');
        print('Precio: $productPrice');
        print('Cantidad: $productQuantity');

        if (productCode.isEmpty ||
            productName.isEmpty ||
            productPrice.isEmpty ||
            productQuantity.isEmpty) {
          print('Error: Faltan campos obligatorios');
          Get.snackbar(
              'Error', 'Por favor llena todos los campos obligatorios');
          return;
        }

        // Subir la imagen si existe
        if (product['imagen'] != null) {
          print('Subiendo imagen...');
          productImageUrl = await _uploadImageToFirebase(product['imagen']);
          if (productImageUrl == null) {
            print('Error: No se pudo subir la imagen');
            Get.snackbar('Error', 'No se pudo subir la imagen');
            return;
          }
          print('Imagen subida correctamente: $productImageUrl');
        } else {
          print('No se seleccionó una imagen');
        }

        // Verificar si el código de producto ya existe
        print('Verificando si el código de producto ya existe...');
        bool codeExists = await _checkIfProductCodeExists(productCode);
        print('Código de producto existe: $codeExists');

        if (codeExists) {
          print('Error: El código de producto $productCode ya existe');
          Get.snackbar(
              'Error', 'El código de producto $productCode ya existe.');
          return;
        }

        // Convertir cantidad y precio a los tipos adecuados
        int quantity = int.tryParse(productQuantity) ?? 0;
        double price = double.tryParse(productPrice) ?? 0.0;

        // Guardar el producto en Firestore
        print('Guardando producto en Firestore...');
        DocumentReference docRef =
            await FirebaseFirestore.instance.collection('productos').add({
          'negocioId': businessId,
          'codigo': productCode,
          'nombre': productName,
          'cantidad': quantity,
          'precio': price,
          'searchKeywords': _generateSearchKeywords(productName),
          'createdAt': FieldValue.serverTimestamp(),
          'sold': false,
          'imagen': productImageUrl,
        });

        print('Producto guardado con ID: ${docRef.id}');
      }

      print('Todos los productos se guardaron correctamente');
      Get.snackbar('Éxito', 'Productos agregados correctamente');
      _clearProductForm();

      // Imprimir la información de todos los productos agregados
      print('Información de todos los productos agregados:');
      for (var product in productsList) {
        print('Código: ${product['codigo']}');
        print('Nombre: ${product['nombre']}');
        print('Precio: ${product['precio']}');
        print('Cantidad: ${product['cantidad']}');
        print('Imagen: ${product['imagen']}');
        print('-------------------------');
      }
    } catch (e) {
      print('Error al guardar productos: $e');
      Get.snackbar('Error', 'Ocurrió un error al guardar los productos');
    }
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

  void _showProductsDialog(List<Map<String, dynamic>> products) {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Productos del Negocio'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                if (isPortrait)
                  ...products.map((product) {
                    return ListTile(
                      title: Text(product['nombre']),
                      subtitle: Text('Código: ${product['codigo']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              _showEditProductBottomSheet(product);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              _deleteProductBusiness(product['id']);
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                if (!isPortrait)
                  DataTable(
                    columns: [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Precio')),
                      DataColumn(label: Text('Cantidad')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: products.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(Text(product['codigo'])),
                          DataCell(Text(product['nombre'])),
                          DataCell(Text(product['precio'].toString())),
                          DataCell(Text(product['cantidad'].toString())),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    _showEditProductBottomSheet(product);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    _deleteProduct(product['id']);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
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

  // Guardar producto actual
// Guardar producto actual

  void _saveCurrentProduct() {
    print('Guardando producto en la lista...');

    if (productControllers.isEmpty) {
      print('Error: No hay productos en productControllers');
      Get.snackbar('Error', 'Debes agregar al menos un producto');
      return;
    }

    // Obtener el último producto ingresado en los controladores
    final int lastIndex = productControllers.length - 1;
    final TextEditingController codigoController =
        productControllers[lastIndex]['codigo'];
    final TextEditingController nombreController =
        productControllers[lastIndex]['nombre'];
    final TextEditingController precioController =
        productControllers[lastIndex]['precio'];
    final TextEditingController cantidadController =
        productControllers[lastIndex]['cantidad'];
    final dynamic imagen = productControllers[lastIndex]
        ['imagen']; // Puede ser un File o String (URL)

    // Extraer valores de los controladores
    final String codigo = codigoController.text.trim();
    final String nombre = nombreController.text.trim();
    final String precio = precioController.text.trim();
    final String cantidad = cantidadController.text.trim();

    // Validar que los campos no estén vacíos
    if (codigo.isEmpty ||
        nombre.isEmpty ||
        precio.isEmpty ||
        cantidad.isEmpty) {
      print('Error: Algunos campos están vacíos');
      Get.snackbar('Error', 'Todos los campos son obligatorios');
      return;
    }

    if (editingIndex != null) {
      // Modo edición: Actualizar el producto existente
      setState(() {
        productsList[editingIndex!] = {
          'codigo': codigo,
          'nombre': nombre,
          'precio': precio,
          'cantidad': cantidad,
          'imagen': imagen, // Puede ser null, File o URL
        };
        editingIndex = null; // Salir del modo edición
      });

      print('Producto actualizado correctamente:');
    } else {
      // Validar si el producto ya está en la lista (por código)
      bool productoExistente =
          productsList.any((product) => product['codigo'] == codigo);

      if (productoExistente) {
        print('Error: El producto con código $codigo ya existe en la lista');
        Get.snackbar('Error', 'El código de producto ya está en la lista');
        return;
      }

      // Agregar producto a la lista
      setState(() {
        productsList.add({
          'codigo': codigo,
          'nombre': nombre,
          'precio': precio,
          'cantidad': cantidad,
          'imagen': imagen, // Puede ser null si no se ha seleccionado imagen
        });
      });

      print('Producto agregado correctamente:');
    }

    // Imprimir la lista después de agregar o actualizar el producto
    for (var product in productsList) {
      print('Código: ${product['codigo']}');
      print('Nombre: ${product['nombre']}');
      print('Precio: ${product['precio']}');
      print('Cantidad: ${product['cantidad']}');
      print('Imagen: ${product['imagen']}');
      print('-------------------------');
    }

    // Limpiar los campos después de guardar
    _clearProductFields();
  }

  void _clearProductFields() {
    setState(() {
      if (productControllers.isNotEmpty) {
        productControllers.last['codigo'].clear();
        productControllers.last['nombre'].clear();
        productControllers.last['precio'].clear();
        productControllers.last['cantidad'].clear();
        productControllers.last['imagen'] = null;
      }
    });
    print('Campos de producto limpiados');
  }

  void _deleteProduct(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar producto'),
        content: Text('¿Estás seguro de que deseas eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
            },
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                productsList.removeAt(index); // Eliminar el producto
              });
              Navigator.pop(context); // Cerrar el diálogo
            },
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _deleteProductBusiness(String productId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar Producto'),
          content: Text('¿Estás seguro de que deseas eliminar este producto?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                // Eliminar el producto de Firestore
                await FirebaseFirestore.instance
                    .collection('productos')
                    .doc(productId)
                    .delete();

                Navigator.of(context).pop(); // Cerrar el diálogo
                Get.snackbar('Éxito', 'Producto eliminado correctamente');
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showEditProductBottomSheet(Map<String, dynamic> product) {
    final TextEditingController _codigoController =
        TextEditingController(text: product['codigo']);
    final TextEditingController _nombreController =
        TextEditingController(text: product['nombre']);
    final TextEditingController _precioController =
        TextEditingController(text: product['precio'].toString());
    final TextEditingController _cantidadController =
        TextEditingController(text: product['cantidad'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Editar Producto', style: TextStyle(fontSize: 18)),
                TextField(
                  controller: _codigoController,
                  decoration: InputDecoration(labelText: 'Código'),
                ),
                TextField(
                  controller: _nombreController,
                  decoration: InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: _precioController,
                  decoration: InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _cantidadController,
                  decoration: InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () async {
                    // Lógica para actualizar el producto en Firestore
                    await FirebaseFirestore.instance
                        .collection('productos')
                        .doc(product['id'])
                        .update({
                      'codigo': _codigoController.text,
                      'nombre': _nombreController.text,
                      'precio': double.parse(_precioController.text),
                      'cantidad': int.parse(_cantidadController.text),
                    });

                    Navigator.of(context).pop(); // Cerrar el BottomSheet
                    Get.snackbar('Éxito', 'Producto actualizado correctamente');
                  },
                  child: Text('Guardar Cambios'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //Index].
  void _editProduct(int index) {
    final product = productsList[index];

    productControllers.last['codigo']!.text = product['codigo'];
    productControllers.last['nombre']!.text = product['nombre'];
    productControllers.last['precio']!.text = product['precio'];
    productControllers.last['cantidad']!.text = product['cantidad'];

    // Manejo seguro de la imagen
    if (product['imagen'] != null) {
      if (product['imagen'] is File) {
        // Si ya es un File, lo asignamos directamente
        productControllers.last['imagen'] = product['imagen'];
      } else if (product['imagen'] is String) {
        // Si es una URL, no podemos asignarla como File, pero podríamos descargarla si es necesario
        print("La imagen es una URL: ${product['imagen']}");
        // Aquí podrías convertir la URL en un File si lo requieres, pero eso depende de tu flujo de trabajo
      }
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
              Scaffold.of(context).openDrawer();
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
                Get.to(SalespointNewSalePage());
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
                    icon: Icon(Icons.home, color: Colors.white),
                    onPressed: () {
                      Get.to(SalespointNewSalePage());
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
                      decoration: InputDecoration(
                        labelText: 'Código',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.camera_alt),
                       onPressed: () async {
  // Abre la cámara para escanear el código de barras y pasa el nombre de la pantalla actual
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BarcodeScannerPage(previousRoute: 'productos'), // Cambia según la pantalla
    ),
  );

  if (result != null && result['barcode'] != null) {
    String scannedBarcode = result['barcode'];

    // Asigna el código escaneado al campo de texto del producto
    productController['codigo']?.text = scannedBarcode;
  }
}

                        ),
                      ),
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
              // Validar que se haya seleccionado un negocio
              if (selectedBusinessId == null) {
                Get.snackbar('Error', 'Por favor selecciona un negocio');

                return;
              }

              // Validar que todos los campos estén llenos

              // Imprimir la lista de productos antes de guardar
              print('Lista de productos antes de guardar:');
              for (var product in productsList) {
                print('Código: ${product['codigo']}');
                print('Nombre: ${product['nombre']}');
                print('Precio: ${product['precio']}');
                print('Cantidad: ${product['cantidad']}');
                print('Imagen: ${product['imagen']}');
                print('-------------------------');
              }

              // Si todo está correcto, guardar los productos
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
        ? Center(child: Text('No hay productos agregados.'))
        : SingleChildScrollView(
            scrollDirection:
                Axis.horizontal, // Permite desplazamiento horizontal
            child: DataTable(
              columns: [
                DataColumn(label: Text('Código')),
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
                        : Image.file(
                            // Usar Image.file para mostrar el archivo en caché
                            product['imagen'], // Asegúrate de que sea un File
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                          ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _editProduct(index);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _deleteProduct(index);
                          },
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          );
  }

  // Método para construir la lista de negocios
  Widget _buildBusinessList() {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

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

        // Si es modo vertical, mostramos una lista de negocios
        if (isPortrait) {
          return ListView.builder(
            itemCount: businesses.length,
            itemBuilder: (context, index) {
              final business = businesses[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  leading: business['logo'] != null
                      ? Image.network(
                          business['logo'],
                          height: 50,
                          width: 50,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.business, size: 50),
                  title: Text(business['nombreEmpresa']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dueño: ${business['nombreDueno']}'),
                      Text('Teléfono: ${business['telefono']}'),
                    ],
                  ),
                  onTap: () async {
                    // Obtener los productos del negocio seleccionado
                    final products =
                        await _fetchProductsForBusiness(business['id']);
                    _showProductsDialog(
                        products); // Mostrar productos en un diálogo
                  },
                ),
              );
            },
          );
        }

        // Si es modo horizontal, mostramos una tabla de negocios
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
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
                        ? Image.network(
                            business['logo'],
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.business, size: 50),
                  ),
                  DataCell(Text(business['nombreEmpresa'])),
                  DataCell(Text(business['nombreDueno'])),
                  DataCell(Text(business['telefono'])),
                ],
                onSelectChanged: (selected) async {
                  // Obtener los productos del negocio seleccionado
                  final products =
                      await _fetchProductsForBusiness(business['id']);
                  _showProductsDialog(
                      products); // Mostrar productos en un diálogo
                },
              );
            }).toList(),
          ),
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

  // Método para mostrar el diálogo con productos del negocio

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

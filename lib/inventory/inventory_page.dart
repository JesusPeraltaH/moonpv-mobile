import 'package:firebase_auth/firebase_auth.dart';
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

  final ImagePicker picker = ImagePicker();
  // Controladores para los campos del formulario del negocio
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _categoriaController = TextEditingController();
  bool _creandoCategoria = false;
  // Variables adicionales para el estado
  String? selectedCategoryId;
  List<File> _tempAdditionalImages = [];
  bool _isSaving = false;


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

 Future<void> _pickImageProducts(int productIndex, {bool isMainImage = true}) async {
  await showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Galería'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageAndSet(productIndex, ImageSource.gallery, isMainImage);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('Cámara'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageAndSet(productIndex, ImageSource.camera, isMainImage);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _pickImageAndSet(int productIndex, ImageSource source, bool isMainImage) async {
  final pickedFile = await picker.pickImage(source: source);
  if (pickedFile != null) {
    final File imageFile = File(pickedFile.path);
    final File cachedImageFile = await _copyFileToCache(imageFile);

    setState(() {
      if (isMainImage) {
        productControllers[productIndex]['imagen'] = cachedImageFile;
      } else {
        productControllers[productIndex]['storeImgs'] ??= [];
        productControllers[productIndex]['storeImgs'].add(cachedImageFile);
      }
    });
  }
}

  Future<File> _copyFileToCache(File originalFile) async {
    final directory = await getTemporaryDirectory();
    final String newPath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await originalFile.copy(newPath);
  }

// Método para copiar el archivo a la caché

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

  void _clearForm() {
    setState(() {
      // Limpiar controladores
      _companyNameController.clear();
      _ownerNameController.clear();
      _phoneController.clear();

      // Limpiar imagen
      _image = null;

      // Resetear otros estados si existen
      // _isLoading = false;
      // _errorMessage = null;
      // _selectedCategory = null;
    });
  }

// Método para seleccionar imágenes

// Método para eliminar imágenes adicionales
  void _removeAdditionalImage(int productIndex, File imageToRemove) {
    setState(() {
      productControllers[productIndex]['storeImgs']
          .removeWhere((file) => file.path == imageToRemove.path);
    });
  }

// Método para guardar productos (actualizado)
 Future<void> _addProducts(String businessId) async {
  setState(() {
    _isSaving = true;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();

    for (var product in productsList) {
      // Subir imagen principal
      String? mainImageUrl;
      if (product['imagen'] != null) {
        mainImageUrl = await _uploadImage(
          product['imagen'],
          'products/$businessId/${product['codigo']}_main',
        );
      }

      // Subir imágenes adicionales
      List<String> additionalImageUrls = [];
      for (var image in product['storeImgs'] ?? []) {
        final url = await _uploadImage(
          image,
          'products/$businessId/${product['codigo']}_additional_${DateTime.now().millisecondsSinceEpoch}',
        );
        additionalImageUrls.add(url);
      }

      List<String> generateSearchKeywords(String name) {
        final normalized = name.trim().toLowerCase();
        List<String> keywords = [];
        for (int i = 1; i <= normalized.length; i++) {
          keywords.add(normalized.substring(0, i));
        }
        return keywords;
      }

      final nombre = product['nombre'];
      final searchKeywords = generateSearchKeywords(nombre);

      final productData = {
        'codigo': product['codigo'],
        'nombre': nombre,
        'searchKeywords': searchKeywords,
        'precio': double.parse(product['precio']),
        'cantidad': int.parse(product['cantidad']),
        'imagen': mainImageUrl,
        'storeImgs': additionalImageUrls,
        'categoriaId': product['categoriaId'],
        'negocioId': businessId,
        'fechaCreacion': FieldValue.serverTimestamp(),
      };

      final productRef = FirebaseFirestore.instance.collection('productos').doc();
      batch.set(productRef, productData);
    }

    await batch.commit();
    _resetForm();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Productos guardados exitosamente')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al guardar productos: $e')),
    );
  } finally {
    setState(() {
      _isSaving = false;
    });
  }
}

void _resetForm() {
  setState(() {
    // Liberar controladores anteriores
    for (var controller in productControllers) {
      (controller['codigo'] as TextEditingController).dispose();
      (controller['nombre'] as TextEditingController).dispose();
      (controller['precio'] as TextEditingController).dispose();
      (controller['cantidad'] as TextEditingController).dispose();
      controller['storeImgs']?.clear(); // limpieza manual adicional
    }

    // Limpiar referencias
    productControllers.clear();
    productsList.clear();
    selectedBusinessId = null;
    selectedCategoryId = null;
    editingIndex = null;

    // Crear nuevo formulario limpio
    productControllers = [
      {
        'codigo': TextEditingController(),
        'nombre': TextEditingController(),
        'precio': TextEditingController(),
        'cantidad': TextEditingController(),
        'imagen': null,
        'storeImgs': [],
      }
    ];
  });
}

  Future<String> _uploadImage(File image, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }
  // Agregar productos a Firestore

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

  void _saveCurrentProduct() {
  print('Guardando producto en la lista...');

  if (productControllers.isEmpty) {
    print('Error: No hay productos en productControllers');
    Get.snackbar('Error', 'Debes agregar al menos un producto');
    return;
  }

  final int lastIndex = productControllers.length - 1;
  final TextEditingController codigoController = productControllers[lastIndex]['codigo'];
  final TextEditingController nombreController = productControllers[lastIndex]['nombre'];
  final TextEditingController precioController = productControllers[lastIndex]['precio'];
  final TextEditingController cantidadController = productControllers[lastIndex]['cantidad'];
  final dynamic imagen = productControllers[lastIndex]['imagen'];
  final List<dynamic> storeImgs = productControllers[lastIndex]['storeImgs'] ?? [];

  final String codigo = codigoController.text.trim();
  final String nombre = nombreController.text.trim();
  final String precio = precioController.text.trim();
  final String cantidad = cantidadController.text.trim();

  if (codigo.isEmpty || nombre.isEmpty || precio.isEmpty || cantidad.isEmpty) {
    print('Error: Algunos campos están vacíos');
    Get.snackbar('Error', 'Todos los campos son obligatorios');
    return;
  }

  if (selectedCategoryId == null) {
    print('Error: Categoría no seleccionada');
    Get.snackbar('Error', 'Debes seleccionar una categoría');
    return;
  }

  Map<String, dynamic> newProduct = {
    'codigo': codigo,
    'nombre': nombre,
    'precio': precio,
    'cantidad': cantidad,
    'imagen': imagen,
    'storeImgs': storeImgs,
    'categoriaId': selectedCategoryId,
  };

  if (editingIndex != null) {
    setState(() {
      productsList[editingIndex!] = newProduct;
      editingIndex = null;
    });

    print('Producto actualizado correctamente:');
  } else {
    bool productoExistente = productsList.any((product) => product['codigo'] == codigo);

    if (productoExistente) {
      print('Error: El producto con código $codigo ya existe en la lista');
      Get.snackbar('Error', 'El código de producto ya está en la lista');
      return;
    }

    setState(() {
      productsList.add(newProduct);
    });

    print('Producto agregado correctamente:');
  }

  for (var product in productsList) {
    print('Código: ${product['codigo']}');
    print('Nombre: ${product['nombre']}');
    print('Precio: ${product['precio']}');
    print('Cantidad: ${product['cantidad']}');
    print('Imagen: ${product['imagen']}');
    print('Imágenes adicionales: ${product['storeImgs']}');
    print('Categoría ID: ${product['categoriaId']}');
    print('-------------------------');
  }

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
      productControllers.last['storeImgs'] = [];
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

  void _mostrarBottomSheetCategoria() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nueva Categoría',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoriaController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Electrónicos, Ropa, Alimentos',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _categoriaController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _creandoCategoria
                          ? null
                          : () async {
                              if (_categoriaController.text.trim().isNotEmpty) {
                                setState(() => _creandoCategoria = true);
                                await _crearCategoria(
                                    _categoriaController.text.trim());
                                setState(() => _creandoCategoria = false);
                                _categoriaController.clear();
                                if (mounted) Navigator.pop(context);
                              }
                            },
                      child: _creandoCategoria
                          ? const CircularProgressIndicator()
                          : const Text('Crear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

// Método para crear la categoría en Firestore
  Future<void> _crearCategoria(String nombre) async {
    try {
      await FirebaseFirestore.instance.collection('categories').add({
        'nombre': nombre,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'creadoPor': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categoría "$nombre" creada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear categoría: $e')),
        );
      }
    }
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
        title: const Text('Inventario'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: _mostrarBottomSheetCategoria,
            tooltip: 'Agregar categoría',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black,
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
              color: Colors.black,
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
          Text(
            'Crear Negocio',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(
            height: 50,
          ),
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
          SizedBox(height: 8.0),
          TextField(
            controller: _ownerNameController,
            decoration: InputDecoration(labelText: 'Nombre del dueño'),
          ),
          SizedBox(height: 8.0),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addBusiness,
              child: Text('Guardar Negocio'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agregar Productos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),

          // Selector de negocio (existente)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getBusinesses(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              if (!snapshot.hasData) return CircularProgressIndicator();

              return DropdownButton<String>(
                value: selectedBusinessId,
                onChanged: (String? newValue) =>
                    setState(() => selectedBusinessId = newValue),
                items: snapshot.data!
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

          // Selector de categoría (nuevo)
         StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error al cargar categorías: ${snapshot.error}');
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return DropdownButton<String>(
        value: selectedCategoryId,
        onChanged: (String? newValue) =>
            setState(() => selectedCategoryId = newValue),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('No hay categorías disponibles', style: TextStyle(color: Colors.grey)),
          ),
        ],
        hint: Text('Seleccionar categoría'),
      );
    }

    final categories = snapshot.data!.docs.map((doc) {
      return {
        'id': doc.id,
        'nombre': doc['nombre'],
      };
    }).toList();

    return DropdownButton<String>(
      value: selectedCategoryId,
      onChanged: (String? newValue) =>
          setState(() => selectedCategoryId = newValue),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Sin categoría', style: TextStyle(color: Colors.grey)),
        ),
        ...categories.map<DropdownMenuItem<String>>((category) {
          return DropdownMenuItem<String>(
            value: category['id'],
            child: Text(category['nombre']),
          );
        }).toList(),
      ],
      hint: Text('Seleccionar categoría'),
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
                    // Campos existentes (código, nombre, precio, cantidad)
                    TextField(
                      controller: productController['codigo'],
                      decoration: InputDecoration(
                        labelText: 'Código',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.camera_alt),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BarcodeScannerPage(
                                    previousRoute: 'productos'),
                              ),
                            );
                            if (result != null && result['barcode'] != null) {
                              productController['codigo']?.text =
                                  result['barcode'];
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: productController['nombre'],
                      decoration: InputDecoration(labelText: 'Nombre'),
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: productController['precio'],
                      decoration: InputDecoration(labelText: 'Precio'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      controller: productController['cantidad'],
                      decoration: InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16.0),
                    // Imagen principal
                    GestureDetector(
                      onTap: () => _pickImageProducts(index, isMainImage: true),
                      child: Container(
                        height: 100,
                        width: 100,
                        color: Colors.white,
                        child: productController['imagen'] == null
                            ? Icon(Icons.add_a_photo, size: 50)
                            : Image.file(productController['imagen'],
                                fit: BoxFit.cover),
                      ),
                    ),
                    Text('Imagen principal', style: TextStyle(fontSize: 12)),

                    SizedBox(height: 8),

                    // Imágenes adicionales (storeImgs)
                    Text('Imágenes MoonStore (opcional)',
                        style: TextStyle(fontSize: 12)),
                    Wrap(
                      spacing: 8,
                      children: [
                        ...(productController['storeImgs'] ?? []).map((file) {
                          return Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      _removeAdditionalImage(index, file),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        IconButton(
                          icon: Icon(Icons.add_a_photo),
                          onPressed: () =>
                              _pickImageProducts(index, isMainImage: false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveCurrentProduct,
              child: Text(editingIndex == null
                  ? 'Agregar otro producto'
                  : 'Actualizar producto'),
            ),
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
            child:SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _isSaving
        ? null
        : () {
            if (selectedBusinessId == null) {
              Get.snackbar('Error', 'Por favor selecciona un negocio');
              return;
            }
            _addProducts(selectedBusinessId!);
          },
    child: _isSaving
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Center(child: Text('Guardar Productos')),
  ),
),

          ),
        ],
      ),
    );
  }

Widget _buildProductTable() {
  return productsList.isEmpty
      ? Center(child: Text('No hay productos agregados.'))
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text('Código')),
              DataColumn(label: Text('Nombre')),
              DataColumn(label: Text('Precio')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Imagen')),
              DataColumn(label: Text('Imágenes Adicionales')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: productsList.map((product) {
              int index = productsList.indexOf(product);
              
              // Asegurarse de que el precio es un número
              double precio = 0.0;
              var rawPrecio = product['precio'];
              if (rawPrecio is int) {
                precio = rawPrecio.toDouble();
              } else if (rawPrecio is double) {
                precio = rawPrecio;
              } else if (rawPrecio is String) {
                precio = double.tryParse(rawPrecio) ?? 0.0;
              }

              return DataRow(cells: [
                DataCell(Text(product['codigo']?.toString() ?? 'N/A')),
                DataCell(Text(product['nombre']?.toString() ?? 'N/A')),
                DataCell(Text('\$${precio.toStringAsFixed(2)}')),
                DataCell(Text(product['cantidad']?.toString() ?? '0')),
                DataCell(
  FutureBuilder<DocumentSnapshot>(
    future: product['categoriaId'] != null
        ? FirebaseFirestore.instance
            .collection('categories')
            .doc(product['categoriaId'])
            .get()
        : FirebaseFirestore.instance
            .collection('categories')
            .doc('_fake_id')
            .get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(),
        );
      }

      return Text(
        snapshot.hasData && snapshot.data?.exists == true
            ? snapshot.data!['nombre']
            : 'Sin categoría',
      );
    },
  ),
),

                DataCell(
                  product['imagen'] == null
                      ? Icon(Icons.image_not_supported, size: 30)
                      : product['imagen'] is File
                          ? Image.file(
                              product['imagen'] as File,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                            )
                          : product['imagen'] is String
                              ? Image.network(
                                  product['imagen'] as String,
                                  height: 50,
                                  width: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.broken_image),
                                )
                              : Icon(Icons.image_not_supported),
                ),
                DataCell(
  (product['storeImgs'] as List?)?.isNotEmpty == true
      ? SizedBox(
          height: 50,
          width: 120, // Ajusta según el máximo ancho esperado
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (product['storeImgs'] as List).map((image) {
                return Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(image),
                    child: image is File
                        ? Image.file(
                            image,
                            height: 40,
                            width: 40,
                            fit: BoxFit.cover,
                          )
                        : image is String
                            ? Image.network(
                                image,
                                height: 40,
                                width: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.broken_image),
                              )
                            : Icon(Icons.image_not_supported),
                  ),
                );
              }).toList(),
            ),
          ),
        )
      : Text('Ninguna'),
),

                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () => _editProduct(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _deleteProduct(index),
                      ),
                    ],
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
}


void _showImageDialog(dynamic image) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        padding: EdgeInsets.all(10),
        child: image is File
            ? Image.file(image)
            : image is String
                ? Image.network(image)
                : Icon(Icons.image_not_supported),
      ),
    ),
  );
}

  // Método para construir la lista de negocios
  Widget _buildBusinessList() {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('negocios').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        List<Map<String, dynamic>> businesses = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        if (isPortrait) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
                child: Text(
                  'Listado de Negocios',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    return Dismissible(
                      key: Key(business['id']),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        String input = '';
                        return await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('¿Eliminar negocio?'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Para confirmar, escribe el nombre completo del dueño:'),
                                  SizedBox(height: 10),
                                  TextField(
                                    onChanged: (value) => input = value,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Nombre del dueño',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (input.trim().toLowerCase() ==
                                        business['nombreDueno']
                                            .toString()
                                            .trim()
                                            .toLowerCase()) {
                                      _deleteBusiness(business['id']);
                                      Navigator.of(context).pop(true);
                                    }
                                  },
                                  child: Text('Eliminar'),
                                )
                              ],
                            );
                          },
                        );
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        color: Colors.red,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        margin: EdgeInsets.symmetric(
                            vertical: 2.0, horizontal: 4.0),
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
                            final products =
                                await _fetchProductsForBusiness(business['id']);
                            _showProductsDialog(products);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

       return SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  child: Row(
    children: businesses.map((business) {
      return GestureDetector(
        onTap: () async {
          final products = await _fetchProductsForBusiness(business['id']);
          _showProductsDialog(products);
        },
        child: Container(
          width: 200,
          margin: EdgeInsets.only(right: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              business['logo'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        business['logo'],
                        height: 80,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 80,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      child: Icon(Icons.business, size: 40, color: Colors.grey),
                    ),
              SizedBox(height: 8),
              Text(
                business['nombreEmpresa'],
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text('Dueño: ${business['nombreDueno']}'),
              Text('Tel: ${business['telefono']}'),
            ],
          ),
        ),
      );
    }).toList(),
  ),
);

      },
    );
  }

  Future<void> _deleteBusiness(String id) async {
    try {
      await FirebaseFirestore.instance.collection('negocios').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Negocio eliminado exitosamente')),
      );
    } catch (e) {
      print('Error al eliminar negocio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar negocio')),
      );
    }
  }


  
}

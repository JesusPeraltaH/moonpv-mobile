import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:moonpv/inventory/Ajustes_screen.dart';
import 'package:moonpv/inventory/main_drawer.dart';
import 'package:moonpv/inventory/sales.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/add_user_screen.dart';
import 'package:moonpv/screens/conteo.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/screens/payment_management_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isSaving = false;
  bool _isSavingBusiness = false;
  Map<String, bool> _isCategorySwipeEnabled = {};
  TextEditingController codigoController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    print('InventoryPage initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('InventoryPage didChangeDependencies');
  }

  @override
  void dispose() {
    print('InventoryPage dispose');
    codigoController.dispose();
    super.dispose();
  }

  Future<void> _pickImageProducts(int productIndex,
      {bool isMainImage = true}) async {
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
                  await _pickImageAndSet(
                      productIndex, ImageSource.gallery, isMainImage);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Cámara'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageAndSet(
                      productIndex, ImageSource.camera, isMainImage);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageAndSet(
      int productIndex, ImageSource source, bool isMainImage) async {
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
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id, // ID del producto
        'codigo': data['codigo'],
        'nombre': data['nombre'],
        'precio': data['precio'],
        'cantidad': data['cantidad'],
        'imagen': data['imagen'],
        'storeImgs': data.containsKey('storeImgs')
            ? (data['storeImgs'] as List<dynamic>).cast<String>()
            : [],
      };
    }).toList();
  }

  // Cargar la imagen desde la galería o la cámara
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final File? pickedFile = await showModalBottomSheet<File>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar imagen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galería'),
                onTap: () async {
                  final List<XFile>? pickedFiles =
                      await picker.pickMultiImage();
                  if (pickedFiles != null && pickedFiles.isNotEmpty) {
                    Navigator.of(context).pop(File(pickedFiles.first
                        .path)); // Tomar la primera imagen si se seleccionan múltiples
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Cámara'),
                onTap: () async {
                  final XFile? pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1800,
                    maxHeight: 1800,
                    imageQuality: 90,
                  );
                  if (pickedFile != null) {
                    Navigator.of(context).pop(File(pickedFile.path));
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    // Actualizar el estado _image con el archivo seleccionado
    setState(() {
      _image = pickedFile;
    });
  }

  Future<List<File>?> _pickMultipleImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      return pickedFiles.map((file) => File(file.path)).toList();
    }
    return null;
  }

  Future<File?> _pickSingleImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery, // O ImageSource.camera
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 90,
    );
    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
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
    setState(() {
      _isSavingBusiness = true; // Inicia el estado de carga
    });

    try {
      if (_companyNameController.text.isEmpty ||
          _ownerNameController.text.isEmpty ||
          _phoneController.text.isEmpty) {
        Get.snackbar('Error', 'Por favor llena todos los campos obligatorios');
        setState(() {
          _isSavingBusiness =
              false; // Detiene el estado de carga en caso de error
        });
        return;
      }

      String? logoUrl;
      if (_image != null) {
        logoUrl = await _uploadImageToFirebase(_image!);
        if (logoUrl == null) {
          Get.snackbar('Error', 'No se pudo subir la imagen');
          setState(() {
            _isSavingBusiness =
                false; // Detiene el estado de carga en caso de error
          });
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
        'activo':
            true, // Campo de bandera "activo" con valor predeterminado true
      });

      Get.snackbar('Éxito', 'Negocio agregado correctamente');
      _clearForm();
    } catch (error) {
      Get.snackbar('Error', 'Hubo un problema al guardar el negocio: $error');
    } finally {
      setState(() {
        _isSavingBusiness = false; // Finaliza el estado de carga
      });
    }
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

        // Generar keywords mejoradas
        final nombre = product['nombre']?.toString() ?? '';
        final searchKeywords = _generateProductKeywords(nombre);

        // Construir datos del producto
        final productData = {
          'codigo': product['codigo'],
          'nombre': nombre,
          'searchKeywords': searchKeywords,
          'precio': double.tryParse(product['precio']?.toString() ?? '0') ?? 0,
          'cantidad': int.tryParse(product['cantidad']?.toString() ?? '0') ?? 0,
          'imagen': mainImageUrl,
          'storeImgs': additionalImageUrls,
          'categoriaId': product['categoriaId'],
          'negocioId': businessId,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        };

        final productRef =
            FirebaseFirestore.instance.collection('productos').doc();
        batch.set(productRef, productData);
      }

      await batch.commit();
      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Productos guardados exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar productos: ${e.toString()}')),
        );
      }
      debugPrint('Error al guardar productos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

// Función mejorada para generar keywords
  List<String> _generateProductKeywords(String productName) {
    if (productName.isEmpty) return [];

    // Normalizar el texto
    final normalized = productName
        .toLowerCase()
        .replaceAll(
            RegExp(r'[^a-z0-9áéíóúüñ ]'), '') // Eliminar caracteres especiales
        .trim();

    // Dividir en palabras y filtrar las muy cortas
    final words = normalized.split(' ')..removeWhere((w) => w.length < 3);

    // Generar variaciones para búsqueda parcial
    final variations = <String>[];
    for (final word in words) {
      // Agregar prefijos de 3 a longitud completa
      for (int i = 3; i <= word.length; i++) {
        variations.add(word.substring(0, i));
      }

      // Agregar palabra completa
      variations.add(word);
    }

    // Agregar el nombre completo y versiones sin espacios
    variations.addAll([
      normalized,
      normalized.replaceAll(' ', ''),
      normalized.replaceAll(' ', '-'),
    ]);

    // Eliminar duplicados y devolver
    return variations.toSet().toList();
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

  void _showProductsDialog(
      List<Map<String, dynamic>> products, Map<String, dynamic> business) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con título y botón de editar negocio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productos del Negocio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditBusinessDialog(business);
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            // Lista de productos
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    title: Text(product['nombre'] ?? 'Sin nombre'),
                    subtitle:
                        Text('Código: ${product['codigo'] ?? 'Sin código'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditProductBottomSheet(product, index);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteProduct(index);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            // Botón de cerrar
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBusinessDialog(Map<String, dynamic> business) {
    final TextEditingController nameController =
        TextEditingController(text: business['nombreEmpresa']);
    final TextEditingController ownerController =
        TextEditingController(text: business['nombreDueno']);
    final TextEditingController phoneController =
        TextEditingController(text: business['telefono']);
    File? _image;
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Container(
            width: double.maxFinite,
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar Negocio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                // Imagen del negocio
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          _image = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : business['logo'] != null &&
                                  business['logo'].isNotEmpty
                              ? Image.network(
                                  business['logo'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.business, size: 50);
                                  },
                                )
                              : Icon(Icons.business, size: 50),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Campos de texto
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Negocio',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: ownerController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del Dueño',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                String? logoUrl = business['logo'];
                                if (_image != null) {
                                  logoUrl =
                                      await _uploadImageToFirebase(_image!);
                                }

                                await FirebaseFirestore.instance
                                    .collection('negocios')
                                    .doc(business['id'])
                                    .update({
                                  'nombreEmpresa': nameController.text,
                                  'nombreDueno': ownerController.text,
                                  'telefono': phoneController.text,
                                  if (logoUrl != null) 'logo': logoUrl,
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Negocio actualizado correctamente')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error al actualizar el negocio: $e')),
                                );
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    final TextEditingController codigoController =
        productControllers[lastIndex]['codigo'];
    final TextEditingController nombreController =
        productControllers[lastIndex]['nombre'];
    final TextEditingController precioController =
        productControllers[lastIndex]['precio'];
    final TextEditingController cantidadController =
        productControllers[lastIndex]['cantidad'];
    final dynamic imagen = productControllers[lastIndex]['imagen'];
    final List<dynamic> storeImgs =
        productControllers[lastIndex]['storeImgs'] ?? [];

    final String codigo = codigoController.text.trim();
    final String nombre = nombreController.text.trim();
    final String precio = precioController.text.trim();
    final String cantidad = cantidadController.text.trim();

    if (codigo.isEmpty ||
        nombre.isEmpty ||
        precio.isEmpty ||
        cantidad.isEmpty) {
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
      bool productoExistente =
          productsList.any((product) => product['codigo'] == codigo);

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

  void _showEditProductBottomSheet(Map<String, dynamic> product, int index) {
    final TextEditingController codigoController =
        TextEditingController(text: product['codigo']?.toString());
    final TextEditingController nombreController =
        TextEditingController(text: product['nombre']);
    final TextEditingController precioController =
        TextEditingController(text: product['precio']?.toString());
    final TextEditingController cantidadController =
        TextEditingController(text: product['cantidad']?.toString());
    File? _image;
    List<File> _storeImages = [];
    bool _isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar Producto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                // Imagen principal del producto
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          _image = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : product['imagen'] != null &&
                                  product['imagen'].isNotEmpty
                              ? Image.network(
                                  product['imagen'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.image, size: 50);
                                  },
                                )
                              : Icon(Icons.image, size: 50),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Sección de imágenes de la tienda
                Text(
                  'Imágenes de la Tienda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Mostrar imágenes existentes
                      if (product['storeImgs'] != null)
                        ...(product['storeImgs'] as List<dynamic>)
                            .map((imgUrl) => Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            imgUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(Icons.image,
                                                  size: 30);
                                            },
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              (product['storeImgs']
                                                      as List<dynamic>)
                                                  .remove(imgUrl);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                      // Mostrar imágenes nuevas seleccionadas
                      ..._storeImages.map((file) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(file, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _storeImages.remove(file);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          )),
                      // Botón para agregar nuevas imágenes
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final List<XFile> images =
                              await picker.pickMultiImage();
                          if (images.isNotEmpty) {
                            setState(() {
                              _storeImages
                                  .addAll(images.map((img) => File(img.path)));
                            });
                          }
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 30),
                              SizedBox(height: 4),
                              Text('Agregar', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Resto de campos
                TextField(
                  controller: codigoController,
                  decoration: InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: precioController,
                  decoration: InputDecoration(
                    labelText: 'Precio',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: cantidadController,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                String? imagenUrl = product['imagen'];
                                if (_image != null) {
                                  imagenUrl =
                                      await _uploadImageToFirebase(_image!);
                                }

                                // Subir nuevas imágenes de la tienda
                                List<String> storeImgsUrls = [];
                                // if (product['storeImgs'] != null) {
                                //   storeImgsUrls.addAll(
                                //       product['storeImgs'] as List<dynamic>);
                                // }

                                for (var file in _storeImages) {
                                  final url =
                                      await _uploadImageToFirebase(file);
                                  if (url != null) {
                                    storeImgsUrls.add(url);
                                  }
                                }

                                await FirebaseFirestore.instance
                                    .collection('productos')
                                    .doc(product['id'])
                                    .update({
                                  'codigo': codigoController.text,
                                  'nombre': nombreController.text,
                                  'precio':
                                      double.tryParse(precioController.text) ??
                                          0.0,
                                  'cantidad':
                                      int.tryParse(cantidadController.text) ??
                                          0,
                                  if (imagenUrl != null) 'imagen': imagenUrl,
                                  'storeImgs': storeImgsUrls,
                                });

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Producto actualizado correctamente')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error al actualizar el producto: $e')),
                                );
                              } finally {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    // Mostrar un diálogo de confirmación
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cerrar sesión'),
          content: Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar el diálogo
                try {
                  await FirebaseAuth.instance
                      .signOut(); // Cerrar sesión en Firebase

                  // Eliminar el estado de autenticación guardado en SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn');
                  await prefs.remove('userId');

                  Get.offAll(() =>
                      LoginScreen()); // Navegar a la pantalla de inicio de sesión
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e')),
                  );
                }
              },
              child: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  //Index].
  void _editProduct(int index) async {
    final product = productsList[index];

    productControllers.last['codigo']!.text = product['codigo'];
    productControllers.last['nombre']!.text = product['nombre'];
    productControllers.last['precio']!.text = product['precio'];
    productControllers.last['cantidad']!.text = product['cantidad'];

    // Manejo seguro de la imagen principal
    if (product['imagen'] != null) {
      if (product['imagen'] is File) {
        productControllers.last['imagen'] = product['imagen'];
      } else if (product['imagen'] is String) {
        print("La imagen principal es una URL: ${product['imagen']}");
        // Si necesitas mostrar la imagen desde URL en la edición,
        // podrías necesitar una forma de cargarla o mostrar un placeholder.
        // Por ahora, no se asigna directamente como File.
        productControllers.last['imagen'] =
            null; // O podrías almacenar la URL temporalmente
      }
    } else {
      productControllers.last['imagen'] = null;
    }

    // Manejo de las imágenes adicionales (storeImgs)
    // Manejo de storeImgs
    if (product['storeImgs'] != null && product['storeImgs'] is List) {
      List storeImgsList = product['storeImgs'];

      List<File> storeImgFiles = [];

      for (var item in storeImgsList) {
        if (item is File) {
          storeImgFiles.add(item);
        } else if (item is String) {
          // Descargar imagen desde la URL
          try {
            final response = await http.get(Uri.parse(item));
            if (response.statusCode == 200) {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File(
                  '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
              await tempFile.writeAsBytes(response.bodyBytes);
              storeImgFiles.add(tempFile);
            }
          } catch (e) {
            print('Error descargando imagen $item: $e');
          }
        }
      }

      productControllers.last['storeImgs'] = storeImgFiles;
    } else {
      productControllers.last['storeImgs'] = <File>[];
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
        'estatus': false,
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
      ),
      drawer: MainDrawer(
        logoutCallback: (context) {
          print('Cerrando sesión desde InventoryPage');
        },
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
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(Icons.business,
                        color: showForm
                            ? Colors.white
                            : Colors.white.withOpacity(0.6)),
                    onPressed: () {
                      setState(() {
                        showForm = true;
                        showProductForm = false;
                        showBusinessProducts = false;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.shopping_cart,
                        color: showProductForm
                            ? Colors.white
                            : Colors.white.withOpacity(0.6)),
                    onPressed: () {
                      setState(() {
                        showForm = false;
                        showProductForm = true;
                        showBusinessProducts = false;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.list,
                        color: showBusinessProducts
                            ? Colors.white
                            : Colors.white.withOpacity(0.6)),
                    onPressed: () {
                      setState(() {
                        showForm = false;
                        showProductForm = false;
                        showBusinessProducts = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.home,
                        color: Get.currentRoute == '/SalespointNewSalePage'
                            ? Colors.white
                            : Colors.white.withOpacity(0.6)),
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
            height: 20,
          ),
          Text('Logo (Sera Visible en MoonStore)'),
          SizedBox(height: 8.0),
          GestureDetector(
            onTap: _pickImage,
            child: Center(
              child: Container(
                height: 150,
                width: 150,
                child: _image == null
                    ? Icon(Icons.add_a_photo, size: 50)
                    : Image.file(_image!, fit: BoxFit.cover),
              ),
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
              onPressed:
                  _isSavingBusiness // Utiliza una variable booleana para el estado de carga
                      ? null
                      : _addBusiness,
              child: _isSavingBusiness
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Guardando...'),
                      ],
                    )
                  : Text('Guardar Negocio'),
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
          SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 2.0,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de negocio
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _getBusinesses(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Text('Error: ${snapshot.error}');
                        if (!snapshot.hasData)
                          return CircularProgressIndicator();

                        List<DropdownMenuItem<String>> items = [
                          DropdownMenuItem<String>(
                            value: null, // Valor para "Sin negocio"
                            child: Text(
                              'Sin negocio',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ...snapshot.data!
                              .map((business) => DropdownMenuItem<String>(
                                    value: business['id'],
                                    child: Text(
                                      business['nombreEmpresa'],
                                      style: TextStyle(
                                        color: selectedBusinessId == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ))
                        ];

                        return SizedBox(
                          width: double.infinity,
                          child: Opacity(
                            opacity: selectedBusinessId == null ? 0.5 : 1.0,
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 24.0),
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedBusinessId,
                                    onChanged: (String? newValue) => setState(
                                        () => selectedBusinessId = newValue),
                                    items: items,
                                    hint: Text(
                                      'Seleccionar negocio',
                                      style: TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    underline: Container(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16.0),

                    // Selector de categoría
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 24.0), // Espacio para la flecha
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('categories')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                    'Error al cargar categorías: ${snapshot.error}');
                              }

                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              }

                              String? dropdownValue = selectedCategoryId;
                              List<DropdownMenuItem<String>> items = [];
                              String hintText = 'Seleccionar categoría';
                              TextStyle hintStyle =
                                  TextStyle(color: Colors.grey);

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                items = [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('No hay categorías disponibles',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                ];
                              } else {
                                final categories =
                                    snapshot.data!.docs.map((doc) {
                                  return {
                                    'id': doc.id,
                                    'nombre': doc['nombre'],
                                  };
                                }).toList();

                                items = [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Sin categoría',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...categories.map<DropdownMenuItem<String>>(
                                      (category) {
                                    return DropdownMenuItem<String>(
                                      value: category['id'],
                                      child: Text(category['nombre']),
                                    );
                                  }).toList(),
                                ];
                              }

                              return DropdownButton<String>(
                                isExpanded:
                                    true, // Para que el texto ocupe todo el ancho
                                value: dropdownValue,
                                onChanged: (String? newValue) => setState(
                                    () => selectedCategoryId = newValue),
                                items: items,
                                hint: Text(
                                  hintText,
                                  style: hintStyle,
                                ),
                                underline:
                                    Container(), // Opcional: para quitar la línea inferior
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                          onPressed: () {
                            _showBarcodeScannerBottomSheet(context,
                                (String scannedCode) {
                              print(
                                  'Código escaneado en el BottomSheet: $scannedCode');
                              productController['codigo']?.text = scannedCode;
                              // No necesitas Get.back() aquí ya que el código se pasa directamente
                            });
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
              _addProducts(selectedBusinessId!);
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: 48.0), // Ajusta la altura máxima según necesites
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (selectedBusinessId == null) {
                            Get.snackbar(
                                'Error', 'Por favor selecciona un negocio');
                            return;
                          }
                          _addProducts(selectedBusinessId!);
                        },
                  child: _isSaving
                      ? Center(
                          // Centra el indicador de carga
                          child: SizedBox(
                            height:
                                24.0, // Ajusta el tamaño del indicador si es necesario
                            width: 24.0,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      : Center(child: Text('Guardar Productos')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBarcodeScannerBottomSheet(
      BuildContext context, Function(String) onCodeScanned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el BottomSheet sea más alto
      builder: (BuildContext bc) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            MobileScannerController cameraController =
                MobileScannerController();

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppBar(
                    title: Text('Escanear código de barras'),
                    automaticallyImplyLeading:
                        false, // No mostrar botón "atrás"
                    actions: [
                      IconButton(
                        icon: Icon(Icons.flash_on),
                        onPressed: () => cameraController.toggleTorch(),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () =>
                            Navigator.pop(context), // Cerrar el BottomSheet
                      ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.6, // Ajusta la altura según necesites
                    width: double.infinity,
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: cameraController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final String barcode =
                                  barcodes.first.rawValue ?? "";
                              onCodeScanned(barcode);
                              Navigator.pop(
                                  context); // Cerrar después de escanear
                            }
                          },
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter:
                                BarcodeOverlayPainter(), // Usa tu overlay si lo tienes
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                                children:
                                    (product['storeImgs'] as List).map((image) {
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

  Widget _buildCategoryItem(DocumentSnapshot categoryDoc) {
    final categoryName = categoryDoc['nombre'] as String;
    final categoryId = categoryDoc.id;
    final categoryData = categoryDoc.data() as Map<String, dynamic>;

    // Asegurarte que _isCategorySwipeEnabled tenga el valor correcto
    _isCategorySwipeEnabled.putIfAbsent(
        categoryId, () => categoryData['estatus'] ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('- $categoryName'),
          Switch(
            value: _isCategorySwipeEnabled[categoryId] ?? false,
            onChanged: (value) async {
              setState(() {
                _isCategorySwipeEnabled[categoryId] = value;
              });

              try {
                await FirebaseFirestore.instance
                    .collection('categories')
                    .doc(categoryId)
                    .update({'estatus': value});
                print('Estatus de $categoryName actualizado a $value');
              } catch (e) {
                print('Error actualizando estatus de $categoryName: $e');
                setState(() {
                  _isCategorySwipeEnabled[categoryId] = !value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNegocioItem(DocumentSnapshot negocioDoc) {
    final negocioName = negocioDoc['nombreEmpresa'] as String;
    final negocioId = negocioDoc.id;
    final negocioData = negocioDoc.data() as Map<String, dynamic>;

    // Verificamos si tiene el campo 'activo'
    if (negocioData['activo'] == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('- $negocioName'),
            // Si no tiene 'activo', no mostramos el Switch
            Text('Sin estado'),
          ],
        ),
      );
    }

    // Si tiene el campo 'activo', mostramos el Switch
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('- $negocioName'),
          Switch(
            value: negocioData['activo'] ?? false,
            onChanged: (value) async {
              try {
                // Actualizamos el campo 'activo' en Firestore
                await FirebaseFirestore.instance
                    .collection('negocios')
                    .doc(negocioId)
                    .update({'activo': value});
                print('Estatus de $negocioName actualizado a $value');
              } catch (e) {
                print('Error actualizando estatus de $negocioName: $e');
              }
            },
          ),
        ],
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
    bool _isCategoriesExpanded = false;
    bool _isNegociosExpanded = false;
    Map<String, bool> _isCategorySwipeEnabled = {};
    Map<String, bool> _isLoadingPdf = {};

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
          return SingleChildScrollView(
            // Envolvemos todo en un SingleChildScrollView
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sección de Categorías (Colapsable)
                ExpansionTile(
                  title: Text(
                    'Categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: _isCategoriesExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isCategoriesExpanded = expanded;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _mostrarBottomSheetCategoria,
                          icon: Icon(Icons.add),
                          label: Text('Crear Nueva'),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('categories')
                          .snapshots(),
                      builder: (context, categorySnapshot) {
                        if (categorySnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error al cargar categorías'),
                          );
                        }
                        if (!categorySnapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final categoriesDocs = categorySnapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: categoriesDocs.length,
                          itemBuilder: (context, index) {
                            return _buildCategoryItem(categoriesDocs[index]);
                          },
                        );
                      },
                    ),
                    SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  title: Text(
                    'Negocios Activos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  initiallyExpanded: _isNegociosExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _isNegociosExpanded = expanded;
                    });
                  },
                  children: [
                    SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('negocios')
                          .snapshots(),
                      builder: (context, negociosSnapshot) {
                        if (negociosSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('Error al cargar negocios'),
                          );
                        }
                        if (!negociosSnapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final negociosDocs = negociosSnapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: negociosDocs.length,
                          itemBuilder: (context, index) {
                            return _buildNegocioItem(negociosDocs[index]);
                          },
                        );
                      },
                    ),
                    SizedBox(height: 8),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5.0, vertical: 5.0),
                  child: Text(
                    'Listado de Negocios',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    final businessId = business['id'] as String;
                    final isDarkMode =
                        Theme.of(context).brightness == Brightness.dark;
                    final defaultImage = isDarkMode
                        ? 'assets/images/moon_blanco.png'
                        : 'assets/images/moon_negro.png';

                    return Dismissible(
                      key: Key(business['id']),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        String input = '';
                        bool? result = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('¿Eliminar negocio?'),
                              content: Text(
                                  '¿Estás seguro de que deseas eliminar este negocio?'),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Cancelar'),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: Text('Eliminar'),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        return result ?? false;
                      },
                      onDismissed: (direction) async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('negocios')
                              .doc(businessId)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Negocio eliminado correctamente')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error al eliminar el negocio: $e')),
                          );
                        }
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          final products =
                              await _fetchProductsForBusiness(businessId);
                          _showProductsDialog(products, business);
                        },
                        child: Card(
                          margin: EdgeInsets.symmetric(
                              vertical: 2.0, horizontal: 4.0),
                          child: ListTile(
                            leading: business['logo'] != null &&
                                    business['logo'].isNotEmpty
                                ? Image.network(
                                    business['logo'],
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        defaultImage,
                                        height: 50,
                                        width: 50,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    defaultImage,
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                  ),
                            title: Text(business['nombreEmpresa']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dueño: ${business['nombreDueno']}'),
                                Text('Teléfono: ${business['telefono']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isLoadingPdf[businessId] == true)
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: Icon(Icons.print),
                                    onPressed: () async {
                                      setState(() {
                                        _isLoadingPdf[businessId] = true;
                                      });
                                      try {
                                        final products =
                                            await _fetchProductsForBusiness(
                                                businessId);
                                        if (products.isNotEmpty) {
                                          final pdfFile =
                                              await _generateProductPdf(
                                                  business['nombreEmpresa'],
                                                  products);
                                          if (pdfFile != null) {
                                            await _saveAndOpenPdf(pdfFile,
                                                '${business['nombreEmpresa']}_productos');
                                          }
                                        }
                                      } finally {
                                        setState(() {
                                          _isLoadingPdf[businessId] = false;
                                        });
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        // Modo no portrait (horizontal)
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: businesses.map((business) {
              final businessId = business['id'] as String;
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              final defaultImage = isDarkMode
                  ? 'assets/images/moon_blanco.png'
                  : 'assets/images/moon_negro.png';

              return GestureDetector(
                onTap: () async {
                  setState(() {
                    _isLoadingPdf[businessId] = true;
                  });
                  try {
                    final products =
                        await _fetchProductsForBusiness(businessId);
                    if (products.isNotEmpty) {
                      final pdfFile = await _generateProductPdf(
                          business['nombreEmpresa'], products);
                      if (pdfFile != null) {
                        await _saveAndOpenPdf(
                            pdfFile, '${business['nombreEmpresa']}_productos');
                      }
                    }
                  } finally {
                    setState(() {
                      _isLoadingPdf[businessId] = false;
                    });
                  }
                },
                child: Container(
                  width: 200,
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: Theme.of(context).dividerColor),
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
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              business['logo'],
                              height: 80,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  defaultImage,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          if (_isLoadingPdf[businessId] == true)
                            Container(
                              height: 80,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.3),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        business['nombreEmpresa'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Dueño: ${business['nombreDueno']}',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Teléfono: ${business['telefono']}',
                        style: TextStyle(fontSize: 14),
                      ),
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

  Future<File?> _generateProductPdf(
      String businessName, List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text('Productos de $businessName')),
        pw.Table.fromTextArray(
          headers: <String>['Código', 'Nombre', 'Cantidad', 'Precio'],
          data: products
              .map((product) => <String>[
                    product['codigo'] ?? '',
                    product['nombre'] ?? '',
                    product['cantidad']?.toString() ?? '0',
                    product['precio']?.toStringAsFixed(2) ?? '0.00',
                  ])
              .toList(),
        ),
      ],
    ));

    try {
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/productos_$businessName.pdf');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      print('Error generating PDF: $e');
      return null;
    }
  }

  Future<void> _saveAndOpenPdf(File pdfFile, String businessName) async {
    final result = await OpenFile.open(pdfFile.path);

    if (result.type != ResultType.done) {
      print('Error al abrir el PDF: ${result.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF.')),
      );
    }
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

// Recuerda tener tu BarcodeOverlayPainter definido si lo estás usando.
class BarcodeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final double guideWidth = size.width * 0.8;
    final double guideHeight = 100;
    final double left = (size.width - guideWidth) / 2;
    final double top = (size.height * 0.6 - guideHeight) /
        2; // Centrar en la vista de la cámara

    final Rect guideRect = Rect.fromLTWH(left, top, guideWidth, guideHeight);
    canvas.drawRect(guideRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

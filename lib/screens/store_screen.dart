import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:moonpv/model/producto_model.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedBusiness = 'Todos';
  String _selectedCategory = 'Todos';
  String? _selectedCategoryId = 'Todos';
  List<Product> _products = [];
  final _debouncer = Debouncer(milliseconds: 500);
  List<String> _recentSearches = [];
  String? _lastSearchQuery;
  List<DocumentSnapshot> _displayedProducts = [];

  // Categorías y negocios pueden venir de Firestore también

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Todos';
    _filterProductsByCategory();
    _loadInitialProducts();
  }

  @override
  void dispose() {
    _debouncer._timer?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _getProductQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('productos')
        .where('cantidad', isGreaterThan: 0);

    if (_selectedCategoryId != 'Todos' && _selectedCategoryId != null) {
      print('Filtrando por categoriaId: $_selectedCategoryId');
      query = query.where('categoriaId', isEqualTo: _selectedCategoryId);
    } else {
      print('Mostrando todos los productos');
    }
    print(
        'Consulta base generada: ${query.parameters}'); // Imprime los parámetros de la consulta
    return query;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      drawerEdgeDragWidth: 40,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.grey.shade200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/moon_blanco.png'
                          : 'assets/images/moon_negro.png',
                      height: 50,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MoonConcept',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('Pedidos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navegar a pedidos
              },
            ),
            ListTile(
              leading: Icon(Icons.favorite),
              title: Text('Favoritos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navegar a favoritos
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Cerrar sesión'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Colors.white,
              expandedHeight: 230.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.only(
                      left: 120, bottom: 0, right: 0, top: 50),
                  child: Image.asset(
                    isDark
                        ? 'assets/images/moon_blanco.png'
                        : 'assets/images/moon_negro.png',
                    height: 150,
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                onSearchTap: () {
                  showSearch(
                    context: context,
                    delegate: ProductSearchDelegate(
                        onProductTap: _showProductDetails),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        ' Desliza desde la izquierda o toca aquí para más opciones',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildCategoriesSection(),
                  _buildBusinessesSection(),
                  _buildRecentSearches(),
                ],
              ),
            ),
            ProductListSection(
              // <- ProductListSection ahora devuelve un Sliver
              selectedCategory: _selectedCategory,
              showProductDetails: _showProductDetails,
              getProductQuery: _getProductQuery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Categorías',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 50,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('categories').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error al cargar categorías');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              // Crear lista de categorías comenzando con "Todos"
              final categories = ['Todos'];
              final categoryDocs = snapshot.data!.docs;
              categories.addAll(
                  categoryDocs.map((doc) => doc['nombre'] as String).toList());

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final categoryName = categories[index];
                  String? categoryId;
                  if (index > 0) {
                    categoryId = categoryDocs[index - 1]
                        .id; // Obtener el ID del documento
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId =
                            categoryId; // Actualizar _selectedCategoryId con el ID
                        print(
                            'Categoría seleccionada: $categoryName, ID: $_selectedCategoryId');
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == categoryId ||
                                (_selectedCategoryId == 'Todos' &&
                                    categoryName == 'Todos')
                            ? Colors.black
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(categoryName,
                            style: TextStyle(
                                color: _selectedCategoryId == categoryId ||
                                        (_selectedCategoryId == 'Todos' &&
                                            categoryName == 'Todos')
                                    ? Colors.white
                                    : Colors.black)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

// Función para filtrar productos según categoría seleccionada
  Future<void> _filterProductsByCategory() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('productos')
          .where('cantidad', isGreaterThan: 0);

      try {
        if (_selectedCategory != 'Todos') {
          // Primero obtenemos el ID de la categoría seleccionada
          final categoryQuery = await FirebaseFirestore.instance
              .collection('categories')
              .where('nombre', isEqualTo: _selectedCategory)
              .limit(1)
              .get();

          if (categoryQuery.docs.isNotEmpty) {
            final categoryId = categoryQuery.docs.first.id;
            query = query.where('categoriaId', isEqualTo: categoryId);
          }
        }
      } catch (e) {
        print("Error al obtener o aplicar filtro de categoría: $e");
        // Aquí podrías manejar el error de la consulta de categorías,
        // por ejemplo, mostrando un mensaje al usuario o estableciendo un estado de error.
        return; // Importante salir de la función si hubo un error crítico.
      }

      try {
        final result = await query.get();
        setState(() {
          _products =
              result.docs.map((doc) => Product.fromFirestore(doc)).toList();
        });
      } catch (e) {
        print("Error al obtener la lista de productos filtrados: $e");
        // Aquí podrías manejar el error de la consulta de productos,
        // mostrando un mensaje o estableciendo un estado de error.
      }
    } catch (e) {
      print("Error general en _filterProductsByCategory: $e");
      // Este catch más general podría capturar errores inesperados fuera de las consultas.
    }
  }
// Variables de clase que necesitarás

  Widget _buildBusinessesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('negocios').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final businesses = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Brands',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  final business =
                      businesses[index].data() as Map<String, dynamic>;
                  final logoUrl = business['logo'] as String?;
                  final isDarkMode = Get.isDarkMode;
                  final defaultImage = isDarkMode
                      ? AssetImage('assets/images/moon_blanco.png')
                          as ImageProvider<Object>?
                      : AssetImage('assets/images/moon_negro.png')
                          as ImageProvider<Object>?;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBusiness = businesses[index].id;
                      });
                    },
                    child: Container(
                      width: 60,
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                logoUrl != null && logoUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(logoUrl)
                                    : defaultImage,
                            onBackgroundImageError: (exception, stackTrace) =>
                                print('Error loading image: $exception'),
                          ),
                          //SizedBox(height: 8),
                          // Text(business['nombreEmpresa'] ?? '',
                          //   textAlign: TextAlign.center,
                          //   maxLines: 2,
                          //   overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(8),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentSearches.length,
        itemBuilder: (context, index) {
          final search = _recentSearches[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              // Envuelve el Chip con InkWell
              onTap: () {
                _searchProducts(search);
              },
              child: Chip(
                label: Text(search),
                onDeleted: () {
                  setState(() {
                    _recentSearches.removeAt(index);
                  });
                },
                deleteIcon: Icon(Icons.close, size: 18),
              ),
            ),
          );
        },
      ),
    );
  }

//  Widget _buildProductsSection() {
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Padding(
//         padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
//         child: Text(
//           'Catálogo ${_selectedCategory != 'Todos' ? '(${_selectedCategory})' : ''}',
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       StreamBuilder<QuerySnapshot>(
//         stream: _getFilteredProducts(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }

//           if (snapshot.hasError) {
//             return Center(child: Text('Error al cargar productos'));
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return Center(
//               child: Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   _selectedCategory == 'Todos'
//                       ? 'No hay productos disponibles'
//                       : 'No hay productos en esta categoría',
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ),
//             );
//           }

//           // Filtrar los productos con cantidad mayor a 0
//           final availableProducts = snapshot.data!.docs.where((product) {
//             final productData = product.data() as Map<String, dynamic>;
//             return (productData['cantidad'] ?? 0) > 0;
//           }).toList();

//           if (availableProducts.isEmpty) {
//             return Center(
//               child: Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   _selectedCategory == 'Todos'
//                       ? 'No hay productos disponibles'
//                       : 'No hay productos disponibles en esta categoría',
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ),
//             );
//           }

//           return GridView.builder(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             padding: EdgeInsets.all(16),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//               childAspectRatio: 0.68,
//             ),
//             itemCount: availableProducts.length, // Usar la lista filtrada
//             itemBuilder: (context, index) {
//               final product = availableProducts[index];
//               final productData = product.data() as Map<String, dynamic>;
//               final List<dynamic> storeImgs = productData['storeImgs'] ?? [];
//               final hasImages =
//                   (productData['imageUrl']?.isNotEmpty == true) ||
//                       storeImgs.isNotEmpty;

//               return GestureDetector(
//                 onTap: () => _showProductDetails(product),
//                 child: Card(
//                   elevation: 2,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Theme.of(context).cardColor,
//                           ),
//                           child: hasImages
//                               ? _buildProductImage(productData)
//                               : _buildThemeAwarePlaceholder(context),
//                         ),
//                       ),
//                       Padding(
//                         padding: EdgeInsets.all(8),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               productData['nombre'] ?? 'Sin nombre',
//                               style: TextStyle(
//                                   fontWeight: FontWeight.bold, fontSize: 16),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             SizedBox(height: 4),
//                             Text(
//                               '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
//                               style: TextStyle(color: Colors.green, fontSize: 15),
//                             ),
//                             SizedBox(height: 4),
//                             Text(
//                               'Disponibles: ${productData['cantidad'] ?? 0}',
//                               style: TextStyle(
//                                   color: productData['cantidad'] > 0
//                                       ? Colors.black54
//                                       : Colors.red,
//                                   fontSize: 14),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     ],
//   );
// }

  Future<void> _loadInitialProducts() async {
    try {
      // Lógica para cargar los productos iniciales
      await _getFilteredProducts().first.then((snapshot) {
        try {
          setState(() {
            _displayedProducts = snapshot.docs;
          });
        } catch (e) {
          print("Error en el setState de _loadInitialProducts: $e");
          // Maneja el error al actualizar el estado, por ejemplo,
          // si el widget ya no está en el árbol.
        }
      }).catchError((error) {
        print("Error al obtener el primer snapshot de productos: $error");
        // Maneja el error al obtener el stream o el primer valor del stream.
        // Podrías establecer un estado de error o intentar recargar los datos.
      });
    } catch (e) {
      print("Error general en _loadInitialProducts: $e");
      // Captura cualquier error síncrono que pueda ocurrir.
    }
  }

  Stream<QuerySnapshot> _getFilteredProducts() {
    if (_selectedCategory == 'Todos') {
      return FirebaseFirestore.instance.collection('productos').snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('productos')
          .where('categoria', isEqualTo: _selectedCategory)
          .snapshots();
    }
  }

  Future<void> _searchProducts(String query) async {
    setState(() {
      _lastSearchQuery = query;
      if (query.isNotEmpty && !_recentSearches.contains(query)) {
        _recentSearches.add(query);
        if (_recentSearches.length > 5) {
          _recentSearches.removeAt(0);
        }
      }
      _displayedProducts = [];
    });

    if (query.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('productos')
          .where('searchKeywords', arrayContains: query.toLowerCase())
          .get()
          .then((snapshot) {
        setState(() {
          _displayedProducts = snapshot.docs;
        });
      });
    } else {
      _loadInitialProducts();
    }
  }

  Future<void> _loadSimilarProducts(DocumentSnapshot product) async {
    final productData = product.data() as Map<String, dynamic>;
    final List<String> categories =
        List<String>.from(productData['categorias'] ?? []);

    // Lógica para buscar productos similares basada en categorías y/o la última búsqueda
    Query query = FirebaseFirestore.instance.collection('productos');
    if (categories.isNotEmpty) {
      query = query.where('categorias', arrayContainsAny: categories);
    }
    if (_lastSearchQuery != null && _lastSearchQuery!.isNotEmpty) {
      query = query.where('searchKeywords',
          arrayContains: _lastSearchQuery!.toLowerCase());
    }
    query = query.limit(10);

    query.get().then((snapshot) {
      setState(() {
        _displayedProducts = snapshot.docs;
      });
    });
  }

  void _showProductDetails(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;
    final List<String> images =
        List<String>.from(data['imagenes'] ?? [data['imagen'] ?? '']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ClipRRect(
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['nombre'] ?? '',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                            '\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 12),
                    // ... (Otros detalles del producto) ...
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Lógica para agregar al carrito
                          Navigator.pop(context);
                          _loadSimilarProducts(
                              product); // Cargar similares al cerrar
                        },
                        child: Text('AGREGAR AL CARRITO',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Este bloque se ejecuta cuando el BottomSheet se cierra
      if (_lastSearchQuery != null && _lastSearchQuery!.isNotEmpty) {
        _searchProducts(_lastSearchQuery!); // Recargar la última búsqueda
      } else {
        _loadInitialProducts(); // Si no hay búsqueda reciente, volver a cargar los iniciales
      }
    });
  }

  Widget _buildProductImage(Map<String, dynamic> productData) {
    final isDarkMode = Get.isDarkMode;
    final storeImgs = productData['storeImgs'] as List<dynamic>?;
    final String? imageUrl = productData['imageUrl'];
    final defaultImage = isDarkMode
        ? 'assets/images/moon_negro.png'
        : 'assets/images/moon_blanco.png';

    Widget imageWidget;

    if (imageUrl?.isNotEmpty == true) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.fill, // Usar BoxFit.fill para estirar la imagen
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    } else if (storeImgs != null &&
        storeImgs.isNotEmpty &&
        storeImgs[0]?.isNotEmpty == true) {
      imageWidget = CachedNetworkImage(
        imageUrl: storeImgs[0],
        fit: BoxFit.fill, // Usar BoxFit.fill para estirar la imagen
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    } else {
      imageWidget = Image.asset(
        defaultImage,
        fit: BoxFit
            .fill, // Usar BoxFit.fill para estirar la imagen de relleno también
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      child: SizedBox(
        width: double.infinity,
        child: imageWidget,
      ),
    );
  }

  Widget _buildThemeAwarePlaceholder(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final placeholderImage = isDarkMode
        ? 'assets/images/moon_solo_blanco.png'
        : 'assets/images/moon_solo_negro.png';

    return Center(
      child: Image.asset(
        placeholderImage,
        width: 100,
        height: 100,
        fit: BoxFit.contain,
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
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isLoggedIn');
                await prefs.remove('userId');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
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
}

class ProductSearchDelegate extends SearchDelegate {
  final Function(DocumentSnapshot) onProductTap;

  ProductSearchDelegate({required this.onProductTap});
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Busca algún producto'),
      );
    }
    return _buildSearchResults(query);
  }

  Widget _buildSearchResults(String searchQuery) {
    if (searchQuery.isEmpty) {
      return const Center(
        child: Text('Busca algún producto'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('searchKeywords', arrayContains: searchQuery.toLowerCase())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data!.docs;

        if (results.isEmpty) {
          return Center(
              child: Text('No se encontraron productos para "$searchQuery"'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final product = results[index];
            final data = product.data() as Map<String, dynamic>;

            return ListTile(
              leading: CachedNetworkImage(
                imageUrl: data['imagen'] ?? '',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              title: Text(data['nombre'] ?? ''),
              subtitle:
                  Text('\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}'),
              onTap: () {
                close(context, null);
                onProductTap(product);
              },
            );
          },
        );
      },
    );
  }
}

class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class ProductListSection extends StatefulWidget {
  final String? selectedCategory;
  final Function(DocumentSnapshot) showProductDetails;
  final Query<Map<String, dynamic>> Function()? getProductQuery;

  const ProductListSection({
    Key? key,
    this.selectedCategory,
    required this.showProductDetails,
    this.getProductQuery,
  }) : super(key: key);

  @override
  _ProductListSectionState createState() => _ProductListSectionState();
}

class _ProductListSectionState extends State<ProductListSection> {
  final ScrollController _scrollController = ScrollController();
  final int _limit = 20; // Cantidad de productos a cargar por página
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  List<DocumentSnapshot> _products = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMoreProducts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      print(
          'Categoría cambió de ${oldWidget.selectedCategory} a ${widget.selectedCategory}');
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      _loadMoreProducts();
    }
  }

  void _scrollListener() {
    if (!_isLoading &&
        _hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    Query<Map<String, dynamic>>? baseQuery = widget.getProductQuery?.call();
    if (baseQuery == null) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    Query<Map<String, dynamic>> paginatedQuery = baseQuery.limit(_limit);

    if (_lastDocument != null && _products.isNotEmpty) {
      // Añadimos una verificación si _products no está vacío
      paginatedQuery = paginatedQuery.startAfterDocument(_lastDocument!);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await paginatedQuery.get();
      List<DocumentSnapshot> newProducts = [];
      for (var doc in snapshot.docs) {
        if (doc.data().containsKey('categoriaId') ||
            widget.selectedCategory == 'Todos') {
          newProducts.add(doc);
        } else {
          print('Producto omitido (sin categoriaId): ${doc.id}');
        }
      }

      if (newProducts.isNotEmpty) {
        _lastDocument = newProducts.last;
        _products.addAll(newProducts);
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('Error al cargar productos: $e');
      // Manejar el error aquí
      _hasMore = false; // Importante para detener intentos de carga
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProductImage(Map<String, dynamic> productData) {
    final isDarkMode = Get.isDarkMode;
    final storeImgs = productData['storeImgs'] as List<dynamic>?;
    final String? imageUrl = productData['imageUrl'];
    final defaultImage = isDarkMode
        ? 'assets/images/moon_negro.png'
        : 'assets/images/moon_blanco.png';

    Widget imageWidget;

    if (imageUrl?.isNotEmpty == true) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    } else if (storeImgs != null &&
        storeImgs.isNotEmpty &&
        storeImgs[0]?.isNotEmpty == true) {
      imageWidget = CachedNetworkImage(
        imageUrl: storeImgs[0],
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Icon(Icons.error),
      );
    } else {
      imageWidget = Image.asset(
        defaultImage,
        fit: BoxFit.fill,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      child: imageWidget,
    );
  }

  Widget _buildThemeAwarePlaceholder(BuildContext context) {
    final isDarkMode = Get.isDarkMode;
    final defaultImage = isDarkMode
        ? 'assets/images/moon_negro.png'
        : 'assets/images/moon_blanco.png';
    return Image.asset(
      defaultImage,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.68,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < _products.length) {
              final product = _products[index];
              final productData = product.data() as Map<String, dynamic>;
              final List<dynamic> storeImgs = productData['storeImgs'] ?? [];
              final hasImages = (productData['imagen']?.isNotEmpty == true) ||
                  storeImgs.isNotEmpty;

              return GestureDetector(
                onTap: () => widget.showProductDetails(product),
                child: Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                          ),
                          child: hasImages
                              ? _buildProductImage(productData)
                              : _buildThemeAwarePlaceholder(context),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productData['nombre'] ?? 'Sin nombre',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Disponibles: ${productData['cantidad'] ?? 0}',
                              style: TextStyle(
                                  color: productData['cantidad'] > 0
                                      ? Colors.black54
                                      : Colors.red,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (_hasMore) {
              return Center(child: CircularProgressIndicator());
            } else {
              return SizedBox.shrink();
            }
          },
          childCount: _products.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onSearchTap;

  _SearchBarDelegate({required this.onSearchTap});

  @override
  double get maxExtent => 44.0; // Altura del buscador

  @override
  double get minExtent => 44.0; // Altura del buscador cuando está pegado

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return GestureDetector(
      onTap: onSearchTap,
      child: Container(
        color: Colors.white, // Color de fondo del buscador
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(Icons.search, color: Colors.grey),
              ),
              Text(
                'Buscar productos...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

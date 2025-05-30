import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:moonpv/model/producto_model.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/settings/user_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonpv/inventory/main_drawer.dart';
import 'package:moonpv/screens/favorites_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _cartItems = [];
  bool _showCartButton = false;
  Map<String, bool> _favorites = {}; // Para mantener el estado de favoritos

  String _selectedBusiness = 'Todos';
  String _selectedCategory = 'Todos';
  String? _selectedCategoryId = 'Todos';
  List<Product> _products = [];
  final _debouncer = Debouncer(milliseconds: 500);
  List<String> _recentSearches = [];
  String? _lastSearchQuery;
  List<DocumentSnapshot> _displayedProducts = [];
  DocumentSnapshot? _lastDocument;
  String? _searchQuery;
  ScrollController _scrollController = ScrollController();

  // Categorías y negocios pueden venir de Firestore también

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Todos';
    _searchQuery = "";
    _filterProductsByCategory();
    _loadInitialProducts();
    _loadFavorites();
    _loadCartItems(); // Cargar items del carrito al iniciar
    _scrollController.addListener(() {
      if (_scrollController.offset >=
              _scrollController.position.maxScrollExtent &&
          !_scrollController.position.outOfRange) {
        // Cargar más productos
        _loadMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _debouncer._timer?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _getProductQuery({
    bool isLoadingMore = false,
    DocumentSnapshot? lastDocument,
  }) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('productos')
        .orderBy(FieldPath.documentId);

    if (isLoadingMore && lastDocument != null) {
      query = query.startAfter([lastDocument.id]);
    }

    query = query.limit(10);

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
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.favorite),
              title: Text('Favoritos'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoritesScreen(
                      initialCartItems: _cartItems,
                    ),
                  ),
                );
                // Actualizar el estado del carrito al regresar
                _loadCartItems();
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configuración'),
              onTap: () {
                Get.to(UserSettingsScreen());
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
          controller: _scrollController,
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF757575) // Color para el tema oscuro
                  : Colors.white,
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
      floatingActionButton: _showCartButton
          ? FloatingActionButton.extended(
              onPressed: _showOrderSummary,
              backgroundColor: Colors.blue,
              icon: Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                '${_cartItems.length} ${_cartItems.length == 1 ? 'item' : 'items'}',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
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

              final categoryDocs = snapshot.data!.docs;

              // FILTRAR categorías donde 'estatus' == true
              final activeCategories = categoryDocs
                  .where((doc) =>
                      (doc.data() as Map<String, dynamic>)['estatus'] == true)
                  .toList();

              // Crear lista de nombres de categorías
              final categories = ['Todos'];
              categories.addAll(activeCategories
                  .map((doc) => doc['nombre'] as String)
                  .toList());

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final categoryName = categories[index];
                  String? categoryId;
                  if (index > 0) {
                    categoryId = activeCategories[index - 1]
                        .id; // ID de la categoría activa
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = categoryId;
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

  Future<void> _filterProductsByCategory() async {
    try {
      Query query = _getProductQuery();

      if (_selectedCategory != 'Todos') {
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

      final result = await query.get();
      setState(() {
        _products =
            result.docs.map((doc) => Product.fromFirestore(doc)).toList();
        _lastDocument = result.docs.last;
      });
    } catch (e) {
      print("Error al obtener o aplicar filtro de categoría: $e");
    }
  }

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
                  final defaultImage = Image.asset(
                    isDarkMode
                        ? 'assets/images/moon_negro.png'
                        : 'assets/images/moon_blanco.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ).image;

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
                          )
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

  void _loadProducts() async {
    final query = _getProductQuery();
    final result = await query.get();

    setState(() {
      _products = result.docs.map((doc) => Product.fromFirestore(doc)).toList();
      _lastDocument = result.docs.last;
    });
  }

  void _loadMoreProducts() async {
    try {
      final query =
          _getProductQuery(isLoadingMore: true, lastDocument: _lastDocument);
      final result = await query.get();

      setState(() {
        _products.addAll(result.docs.map((doc) => Product.fromFirestore(doc)));
        if (result.docs.isNotEmpty) {
          _lastDocument = result.docs.last;
        }
      });
    } catch (e) {
      print('Error: $e');
    }
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
                          _addToCart(data);
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

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      // Asegurarnos de que tenemos todos los datos necesarios
      final cartItem = {
        'id': product['id'] ?? '',
        'nombre': product['nombre'] ?? 'Producto sin nombre',
        'precio': product['precio'] ?? 0.0,
        'imagen': product['imagen'] ?? '',
        'cantidad': 1, // Agregamos cantidad por defecto
      };
      _cartItems.add(cartItem);
      _showCartButton = true;
    });
  }

  void _showOrderSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Resumen de la Orden',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return ListTile(
                      leading:
                          item['imagen'] != null && item['imagen'].isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: item['imagen'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.image, size: 50),
                                )
                              : Icon(Icons.image, size: 50),
                      title: Text(item['nombre'] ?? 'Producto'),
                      subtitle: Text(
                          '\$${item['precio']?.toStringAsFixed(2) ?? '0.00'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setState(() {
                                if (item['cantidad'] > 1) {
                                  item['cantidad']--;
                                } else {
                                  _cartItems.removeAt(index);
                                  if (_cartItems.isEmpty) {
                                    _showCartButton = false;
                                  }
                                }
                              });
                              Navigator.pop(context);
                              _showOrderSummary();
                            },
                          ),
                          Text('${item['cantidad']}'),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                item['cantidad']++;
                              });
                              Navigator.pop(context);
                              _showOrderSummary();
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _cartItems.removeAt(index);
                                if (_cartItems.isEmpty) {
                                  _showCartButton = false;
                                }
                              });
                              Navigator.pop(context);
                              _showOrderSummary();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_calculateTotal().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implementar proceso de pago
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    'Proceder al Pago',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateTotal() {
    return _cartItems.fold(0.0, (sum, item) {
      return sum + ((item['precio'] ?? 0.0) * (item['cantidad'] ?? 1));
    });
  }

  // Función para cargar los favoritos del usuario
  Future<void> _loadFavorites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesRef =
          _firestore.collection('userFavorites').doc(user.uid);
      final userFavoritesDoc = await userFavoritesRef.get();

      if (!userFavoritesDoc.exists) {
        // Obtener información adicional del usuario
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};

        // Si no existe el documento, lo creamos con un array vacío y la información del usuario
        await userFavoritesRef.set({
          'userId': user.uid,
          'userEmail': user.email,
          'userName': userData['nombre'] ?? userData['name'] ?? 'Usuario',
          'userRole': userData['role'] ?? 'Cliente',
          'favorites': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _favorites = {};
        });
      } else {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          final List<dynamic> favorites = data['favorites'];
          setState(() {
            _favorites = Map.fromEntries(
              favorites.map((fav) => MapEntry(fav['productId'], true)),
            );
          });
        }
      }
    } catch (e) {
      print('Error al cargar favoritos: $e');
    }
  }

  // Función para manejar el toggle de favoritos
  Future<void> _toggleFavorite(
      String productId, Map<String, dynamic> productData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesRef =
          _firestore.collection('userFavorites').doc(user.uid);
      final userFavoritesDoc = await userFavoritesRef.get();

      if (!userFavoritesDoc.exists) {
        await userFavoritesRef.set({
          'favorites': [
            {
              'productId': productId,
              'productData': productData,
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            }
          ],
        });
        setState(() {
          _favorites[productId] = true;
        });
      } else {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          final List<dynamic> favorites = List.from(data['favorites']);

          final existingIndex =
              favorites.indexWhere((fav) => fav['productId'] == productId);

          if (existingIndex != -1) {
            favorites.removeAt(existingIndex);
            setState(() {
              _favorites.remove(productId);
            });
          } else {
            favorites.add({
              'productId': productId,
              'productData': productData,
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            });
            setState(() {
              _favorites[productId] = true;
            });
          }

          await userFavoritesRef.update({
            'favorites': favorites,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error al actualizar favoritos: $e');
    }
  }

  Future<void> _loadCartItems() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final cartDoc =
          await _firestore.collection('userCart').doc(user.uid).get();

      if (cartDoc.exists) {
        final data = cartDoc.data();
        if (data != null && data['items'] != null) {
          setState(() {
            _cartItems = List<Map<String, dynamic>>.from(data['items']);
            _showCartButton = _cartItems.isNotEmpty;
          });
        }
      } else {
        setState(() {
          _cartItems = [];
          _showCartButton = false;
        });
      }
    } catch (e) {
      print('Error al cargar el carrito: $e');
    }
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
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  List<DocumentSnapshot> _products = [];
  bool _hasMore = true;
  Map<String, bool> _favorites = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadMoreProducts();
    _scrollController.addListener(_scrollListener);
    _loadFavorites();
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    productData['nombre'] ?? 'Sin nombre',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _favorites[product.id] == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _favorites[product.id] == true
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _toggleFavorite(product.id, productData),
                                ),
                              ],
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

  Future<void> _toggleFavorite(
      String productId, Map<String, dynamic> productData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesRef =
          _firestore.collection('userFavorites').doc(user.uid);
      final userFavoritesDoc = await userFavoritesRef.get();

      if (!userFavoritesDoc.exists) {
        await userFavoritesRef.set({
          'favorites': [
            {
              'productId': productId,
              'productData': productData,
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            }
          ],
        });
        setState(() {
          _favorites[productId] = true;
        });
      } else {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          final List<dynamic> favorites = List.from(data['favorites']);

          final existingIndex =
              favorites.indexWhere((fav) => fav['productId'] == productId);

          if (existingIndex != -1) {
            favorites.removeAt(existingIndex);
            setState(() {
              _favorites.remove(productId);
            });
          } else {
            favorites.add({
              'productId': productId,
              'productData': productData,
              'addedAt': DateTime.now().millisecondsSinceEpoch,
            });
            setState(() {
              _favorites[productId] = true;
            });
          }

          await userFavoritesRef.update({
            'favorites': favorites,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error al actualizar favoritos: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesRef =
          _firestore.collection('userFavorites').doc(user.uid);
      final userFavoritesDoc = await userFavoritesRef.get();

      if (!userFavoritesDoc.exists) {
        // Obtener información adicional del usuario
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};

        // Si no existe el documento, lo creamos con un array vacío y la información del usuario
        await userFavoritesRef.set({
          'userId': user.uid,
          'userEmail': user.email,
          'userName': userData['nombre'] ?? userData['name'] ?? 'Usuario',
          'userRole': userData['role'] ?? 'Cliente',
          'favorites': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _favorites = {};
        });
      } else {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          final List<dynamic> favorites = data['favorites'];
          setState(() {
            _favorites = Map.fromEntries(
              favorites.map((fav) => MapEntry(fav['productId'], true)),
            );
          });
        }
      }
    } catch (e) {
      print('Error al cargar favoritos: $e');
    }
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

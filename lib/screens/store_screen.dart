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
import 'package:moonpv/widgets/product_image_widget.dart';
import 'package:moonpv/controllers/cart_controller.dart';
import 'package:moonpv/widgets/cart_bottom_sheet.dart';
import 'package:moonpv/widgets/drawer_store_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, bool> _favorites = {}; // Para mantener el estado de favoritos
  bool _isAppBarVisible =
      false; // Nuevo estado para controlar la visibilidad de la AppBar

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

  // Get the CartController instance
  final CartController cartController = Get.find();

  // Categorías y negocios pueden venir de Firestore también

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Todos';
    _selectedCategoryId = 'Todos';
    _selectedBusiness = 'Todos';
    _searchQuery = "";
    _loadFavorites();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final scrollOffset = _scrollController.offset;
      final expandedHeight = 230.0; // Altura expandida del SliverAppBar
      final threshold =
          expandedHeight - kToolbarHeight; // Umbral para mostrar/ocultar

      if (scrollOffset > threshold && !_isAppBarVisible) {
        setState(() {
          _isAppBarVisible = true;
        });
      } else if (scrollOffset <= threshold && _isAppBarVisible) {
        setState(() {
          _isAppBarVisible = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

    if (_selectedCategoryId != null && _selectedCategoryId != 'Todos') {
      query = query.where('categoriaId', isEqualTo: _selectedCategoryId);
    }

    if (_selectedBusiness != 'Todos') {
      query = query.where('negocioId', isEqualTo: _selectedBusiness);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Get.isDarkMode ? Colors.black : Colors.white,
      drawerEdgeDragWidth: 40,
      drawer: DrawerStoreScreen(
        isDark: isDark,
        onPedidosTap: () {/* TODO: Implement Pedidos navigation */},
        onFavoritesTap: () async {
          Navigator.pop(context); // Close the drawer
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FavoritesScreen(),
            ),
          );
        },
        onSettingsTap: () {
          Get.to(UserSettingsScreen());
        },
        onLogoutTap: () => _logout(context),
      ),
      body: Builder(
        builder: (context) => CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              stretch: true,
              collapsedHeight: _isAppBarVisible ? kToolbarHeight : 0,
              toolbarHeight: _isAppBarVisible ? kToolbarHeight : 0,
              automaticallyImplyLeading: false,
              leading: _isAppBarVisible
                  ? Builder(
                      builder: (context) => IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    )
                  : null,
              title: _isAppBarVisible
                  ? Container(
                      height: kToolbarHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(width: 30),
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: Image.asset(
                                isDark
                                    ? 'assets/images/moon_solo_blanco_recortada.png'
                                    : 'assets/images/moon_solo_negro_recortada.png',
                                height: 30,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Image.asset(
                              isDark
                                  ? 'assets/images/conceptstore_blanco.png'
                                  : 'assets/images/conceptstore.png',
                              height: 30,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: isDark ? Colors.black : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 120, bottom: 0, right: 0, top: 50),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/moon_blanco_recortado.png'
                          : 'assets/images/moon_negro_recortado.png',
                      height: 90,
                    ),
                  ),
                ),
                titlePadding: EdgeInsets.zero,
                centerTitle: true,
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
              selectedCategoryId: _selectedCategoryId,
              selectedBusiness: _selectedBusiness,
              showProductDetails: _showProductDetails,
              getProductQuery: _getProductQuery,
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(
        () => cartController.showCartButton.value
            ? FloatingActionButton.extended(
                onPressed: _showOrderSummary,
                backgroundColor: Get.isDarkMode ? Colors.white : Colors.black,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.shopping_cart,
                            color:
                                Get.isDarkMode ? Colors.black : Colors.white),
                        if (cartController.cartItems.isNotEmpty)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Get.isDarkMode
                                        ? Colors.black
                                        : Colors.white,
                                    width: 1.5),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Obx(() => Text(
                                    '${cartController.cartItems.length}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            : Container(), // Use Container() or SizedBox.shrink() for the hidden state
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

              final categoryDocs = snapshot.data!.docs;

              // FILTRAR categorías donde 'estatus' == true
              final activeCategories = categoryDocs
                  .where((doc) =>
                      (doc.data() as Map<String, dynamic>)['estatus'] == true)
                  .toList();

              // Crear lista de nombres de categorías
              final categories = [
                {'name': 'Todos', 'id': 'Todos'}
              ];
              categories.addAll(activeCategories
                  .map((doc) => {'name': doc['nombre'] as String, 'id': doc.id})
                  .toList());

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final categoryName = category['name'];
                  final categoryId = category['id'];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (categoryId == 'Todos') {
                          _selectedCategoryId = 'Todos';
                          _selectedBusiness = 'Todos';
                        } else {
                          _selectedCategoryId = categoryId;
                          _selectedBusiness = 'Todos';
                        }
                        print(
                            'Categoría seleccionada: $categoryName, ID: $_selectedCategoryId');
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == categoryId
                            ? Colors.black
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(categoryName!,
                            style: TextStyle(
                                color: _selectedCategoryId == categoryId
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

        final businessesDocs = snapshot.data!.docs;

        // FILTER businesses where 'activo' == true
        final activeBusinessesDocs = businessesDocs
            .where(
                (doc) => (doc.data() as Map<String, dynamic>)['activo'] == true)
            .toList();

        // Add a 'Todos' option at the beginning
        final List<Map<String, dynamic>> businesses = [
          {'name': 'Todos', 'id': 'Todos'}
        ];
        businesses.addAll(activeBusinessesDocs
            .map((doc) => {
                  'name': doc['nombreEmpresa'] as String,
                  'id': doc.id,
                  'logo': doc['logo'] as String?
                }) // Get logo (can be null)
            .toList());

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
                  final business = businesses[index];
                  final businessName = business['name'];
                  final businessId = business['id'];
                  final logoUrl =
                      business['logo'] as String?; // Cast logo to String?
                  final isDarkMode = Get.isDarkMode;

                  // Use a placeholder for the 'Todos' option or if logoUrl is null/empty
                  final ImageProvider backgroundImage;
                  if (businessId == 'Todos' ||
                      logoUrl == null ||
                      logoUrl.isEmpty) {
                    backgroundImage = Image.asset(
                      isDarkMode
                          ? 'assets/images/moon_negro.png'
                          : 'assets/images/moon_blanco.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ).image;
                  } else {
                    backgroundImage = CachedNetworkImageProvider(logoUrl);
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (businessId == 'Todos') {
                          _selectedBusiness = 'Todos';
                          _selectedCategoryId =
                              'Todos'; // Reset category filter
                        } else {
                          _selectedBusiness =
                              businessId as String; // Cast to String
                          _selectedCategoryId =
                              'Todos'; // Reset category filter
                        }
                        print('Negocio seleccionado: $_selectedBusiness');
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
                            backgroundImage: backgroundImage,
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
    // This function is no longer actively used for initial display
    // as initial load is handled by the stream in ProductListSection
    // based on _getProductQuery
  }

  Stream<QuerySnapshot> _getFilteredProducts() {
    // This function is no longer needed as _getProductQuery handles filtering
    // and ProductListSection uses that directly.
    throw UnimplementedError('This method is no longer used');
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
      // _displayedProducts = []; // No longer directly manipulate _displayedProducts here
    });

    // The search logic now needs to trigger a reload in ProductListSection
    // This might require changing how ProductListSection gets its data,
    // potentially passing the search query down or having ProductListSection
    // listen to changes in _lastSearchQuery.
    // For now, we'll leave this as is, but it might not fully integrate
    // with the streamed list without further changes.

    // If you want search to filter the stream, you'd need to modify _getProductQuery
    // to include the search term, which can be complex with Firestore text search.
    // A separate search delegate (ProductSearchDelegate) is already used for a dedicated search screen.
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
      // This part might need adjustment if you want similar products
      // to replace or augment the main product list
      setState(() {
        _displayedProducts = snapshot.docs; // This still updates the old list
      });
    });
  }

  void _loadProducts() async {
    // This is the old load method, likely not used anymore with ProductListSection stream
    // final query = _getProductQuery();
    // final result = await query.get();
    //
    // setState(() {
    //   _products = result.docs.map((doc) => Product.fromFirestore(doc)).toList();
    //   _lastDocument = result.docs.last;
    // });
  }

  void _loadMoreProducts() async {
    // This is the old load more method, handled within ProductListSection now
    // try {
    //   final query =
    //       _getProductQuery(isLoadingMore: true, lastDocument: _lastDocument);
    //   final result = await query.get();
    //
    //   setState(() {
    //     _products.addAll(result.docs.map((doc) => Product.fromFirestore(doc)));
    //     if (result.docs.isNotEmpty) {
    //       _lastDocument = result.docs.last;
    //     }
    //   });
    // } catch (e) {
    //   print('Error: $e');
    // }
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
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
                child: ListView(
                  children: [
                    // Product Images
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
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
                    // Product Details
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  data['nombre'] ?? '',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          // Variants Section
                          Text(
                            'Variantes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 5, // Placeholder count
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 100,
                                  margin: EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image,
                                      color: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[400],
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000000),
                                foregroundColor:
                                    isDark ? Colors.white : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                elevation: isDark ? 4 : 2,
                                shadowColor: isDark
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.2),
                              ),
                              onPressed: () {
                                // Create a new map that includes the document ID as 'id'
                                final productDataWithId = {
                                  ...data,
                                  'id': product
                                      .id, // Use the Firestore document ID as the product ID
                                };
                                print(
                                    'StoreScreen: Adding product to cart: $productDataWithId'); // Debug print
                                cartController.addToCart(
                                    productDataWithId); // Pass the map with the correct ID
                                Navigator.pop(context);
                                _loadSimilarProducts(product);
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
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Decide how to refresh the product list after closing details
      // For now, we'll rely on the ProductListSection's didUpdateWidget if filters change
      // or its own loading logic.
      // if (_lastSearchQuery != null && _lastSearchQuery!.isNotEmpty) {
      //   _searchProducts(_lastSearchQuery!);
      // } else {
      //   _loadInitialProducts();
      // }
    });
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

  void _showOrderSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: CartBottomSheet(),
        );
      },
    );
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
  final String? selectedCategoryId;
  final String? selectedBusiness;
  final Function(DocumentSnapshot) showProductDetails;
  final Query<Map<String, dynamic>> Function()? getProductQuery;

  const ProductListSection({
    Key? key,
    this.selectedCategoryId,
    this.selectedBusiness,
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
    if (widget.selectedCategoryId != oldWidget.selectedCategoryId ||
        widget.selectedBusiness != oldWidget.selectedBusiness) {
      print(
          'Filtro cambiado: Categoría de ${oldWidget.selectedCategoryId} a ${widget.selectedCategoryId}, Negocio de ${oldWidget.selectedBusiness} a ${widget.selectedBusiness}');
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
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
      paginatedQuery = paginatedQuery.startAfterDocument(_lastDocument!);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await paginatedQuery.get();
      List<DocumentSnapshot> newProducts = snapshot.docs;

      if (newProducts.isNotEmpty) {
        _lastDocument = newProducts.last;
        _products.addAll(newProducts);
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('Error al cargar productos: $e');
      _hasMore = false; // Importante para detener intentos de carga
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < _products.length) {
              final product = _products[index];
              final productData = product.data() as Map<String, dynamic>;

              return GestureDetector(
                onTap: () => widget.showProductDetails(product),
                child: Card(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Get.isDarkMode ? Colors.black : Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: ProductImageWidget(productData: productData),
                        ),
                      ),
                      Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productData['nombre'] ?? 'Sin nombre',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.green,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    icon: Icon(
                                      _favorites[product.id] == true
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _favorites[product.id] == true
                                          ? Colors.red
                                          : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.grey),
                                      size: 18,
                                    ),
                                    onPressed: () => _toggleFavorite(
                                        product.id, productData),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onSearchTap;

  _SearchBarDelegate({required this.onSearchTap});

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onSearchTap,
      child: Container(
        color: isDarkMode ? Colors.black : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                spreadRadius: 1.0,
                offset: Offset(0, 0),
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(Icons.search,
                    color: isDarkMode ? Colors.white : Colors.grey, size: 24),
              ),
              if (!isDarkMode)
                Expanded(
                  child: Text(
                    'Buscar productos...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

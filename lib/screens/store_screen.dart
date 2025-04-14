import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonpv/model/producto_model.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedBusiness = 'Todos';
  String _selectedCategory = 'Todos';
  List<Product> _products = [];
  final _debouncer = Debouncer(milliseconds: 500);

  // Categorías y negocios pueden venir de Firestore también
  final List<String> categories = [
    'Todos',
    'Joyeria',
    'Suplementos',
    'Ropa',
    'Tenis',
    'Maquillaje',
    'Skincare'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Todos';
    _filterProductsByCategory();
  }

  @override
  void dispose() {
    _debouncer._timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      drawerEdgeDragWidth: 40, // default = 20. Ajusta si querés más sensible
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
        // <- Necesario para abrir el drawer desde contexto
        builder: (context) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    left: 120, bottom: 0, right: 0, top: 50),
                child: Image.asset(
                  isDark
                      ? 'assets/images/moon_blanco.png'
                      : 'assets/images/moon_negro.png',
                  height: 150,
                ),
              ),
              SizedBox(height: 12),

              // 🔥 Nuevo: Texto interactivo para abrir el drawer
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

              SizedBox(height: 12),

              GestureDetector(
                onTap: () {
                  showSearch(
                      context: context, delegate: ProductSearchDelegate());
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Buscar productos...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildCategoriesSection(),
              _buildBusinessesSection(),
              _buildProductsSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          _debouncer.run(() {
            if (mounted) {
              setState(() {
                _searchQuery = value.trim();
              });
            }
          });
        },
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
              categories.addAll(snapshot.data!.docs
                  .map((doc) => doc['nombre'] as String)
                  .toList());

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = categories[index];
                        _filterProductsByCategory();
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedCategory == categories[index]
                            ? Colors.black
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(categories[index],
                            style: TextStyle(
                                color: _selectedCategory == categories[index]
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
    Query query = FirebaseFirestore.instance
        .collection('productos')
        .where('cantidad', isGreaterThan: 0);

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

    final result = await query.get();
    setState(() {
      _products = result.docs.map((doc) => Product.fromFirestore(doc)).toList();
    });
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
              child: Text('Negocios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: businesses.length,
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBusiness = business.id;
                      });
                    },
                    child: Container(
                      width: 60,
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: CachedNetworkImageProvider(
                                business['logo'] ?? ''),
                          ),
                          //SizedBox(height: 8),
                          // Text(business['nombreEmpresa'] ?? '',
                          //     textAlign: TextAlign.center,
                          //     maxLines: 2,
                          //     overflow: TextOverflow.ellipsis),
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

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
          child: Text(
            'Catálogo ${_selectedCategory != 'Todos' ? '(${_selectedCategory})' : ''}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _getFilteredProducts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar productos'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    _selectedCategory == 'Todos'
                        ? 'No hay productos disponibles'
                        : 'No hay productos en esta categoría',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              );
            }

            final products = snapshot.data!.docs;

            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final productData = product.data() as Map<String, dynamic>;
                final List<dynamic> storeImgs = productData['storeImgs'] ?? [];
                final hasImages =
                    (productData['imageUrl']?.isNotEmpty == true) ||
                        storeImgs.isNotEmpty;

                return GestureDetector(
                  onTap: () => _showProductDetails(product),
                  child: Card(
                    elevation: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contenedor de imágenes
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                            ),
                            child: hasImages
                                ? _buildProductImage(productData, storeImgs)
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
                                style: TextStyle(
                                    color: Colors.green, fontSize: 15),
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
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductImage(
      Map<String, dynamic> productData, List<dynamic> storeImgs) {
    final mainImage = productData['imageUrl']?.isNotEmpty == true
        ? productData['imageUrl']
        : storeImgs.isNotEmpty
            ? storeImgs[0]
            : null;

    return Stack(
      children: [
        if (mainImage != null)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(mainImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (storeImgs.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
              ),
              child: Text(
                '${storeImgs.length + (productData['imageUrl']?.isNotEmpty == true ? 1 : 0)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
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

  List<Map<String, dynamic>> _cartItems = [];

  void _addToCart(DocumentSnapshot product) {
    final productData = product.data() as Map<String, dynamic>;
    final productId = product.id;

    final existingItemIndex =
        _cartItems.indexWhere((item) => item['id'] == productId);

    if (existingItemIndex >= 0) {
      _cartItems[existingItemIndex]['quantity'] += 1;
    } else {
      _cartItems.add({
        'id': productId,
        'name': productData['nombre'],
        'price': productData['precio'],
        'imageUrl': productData['imagen'],
        'quantity': 1,
      });
    }

    setState(() {});
  }

  Stream<QuerySnapshot> _getFilteredProducts() {
    // Consulta base para productos con cantidad > 0
    Query baseQuery = FirebaseFirestore.instance
        .collection('productos')
        .where('cantidad', isGreaterThan: 0);

    // 1. Manejo de búsqueda por keywords si hay query
    if (_searchQuery.isNotEmpty) {
      baseQuery = baseQuery.where(
        'searchKeywords',
        arrayContains: _searchQuery.toLowerCase(),
      );
    }

    // 2. Manejo de categorías
    if (_selectedCategory != 'Todos') {
      return FirebaseFirestore.instance
          .collection('categories')
          .where('nombre', isEqualTo: _selectedCategory)
          .limit(1)
          .snapshots()
          .switchMap((categoryQuery) {
        if (categoryQuery.docs.isEmpty) return baseQuery.snapshots();

        final categoryId = categoryQuery.docs.first.id;
        return baseQuery
            .where('categoriaId', isEqualTo: categoryId)
            .snapshots();
      });
    }

    // 3. Retornar consulta simple si no hay filtros especiales
    return baseQuery.snapshots();
  }

  Widget _buildProductCard(DocumentSnapshot product) {
    final productData = product.data() as Map<String, dynamic>;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del producto con loader
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: CachedNetworkImage(
                imageUrl: productData['imagen'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
          ),
          // Información del producto
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productData['nombre'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${productData['precio'].toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;
    final List<String> images =
        List<String>.from(data['imagenes'] ?? [data['imagen']]);

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
              // Sección deslizable para cerrar
              Container(
                height: 4,
                width: 40,
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Galería de imágenes
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
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Detalles del producto (fijo en la parte inferior)
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

                    // Selector de tallas
                    if (data['tallas'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tallas disponibles:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                List<Widget>.from(data['tallas'].map((talla) {
                              return Chip(
                                label: Text(talla),
                                backgroundColor: Colors.grey[200],
                              );
                            })),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),

                    // Botón de agregar al carrito (MODIFICADO)
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
                          _addToCart(product); // Agregar al carrito
                          Navigator.pop(context); // Cerrar el BottomSheet
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Producto agregado al carrito')),
                          );
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
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
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
    return _buildSearchResults(query);
  }

  Widget _buildSearchResults(String searchQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('nombre', isGreaterThanOrEqualTo: searchQuery)
          .where('nombre', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data!.docs;

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
              ),
              title: Text(data['nombre'] ?? ''),
              subtitle:
                  Text('\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}'),
              onTap: () {
                // Navegar a pantalla de detalle
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

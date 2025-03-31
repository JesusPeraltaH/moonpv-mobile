import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  String _selectedBusiness = 'Todos';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('MoonConcept Store',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {
              showSearch(context: context, delegate: ProductSearchDelegate());
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.black),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            _buildCategoriesSection(),
            _buildBusinessesSection(),
            _buildProductsSection(),
          ],
        ),
      ),
    );
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
          setState(() {
            _searchQuery = value;
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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = categories[index];
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
      // Título Catálogo
      Padding(
        padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
        child: Text(
          'Catálogo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Lista de productos
      StreamBuilder<QuerySnapshot>(
        stream: _getFilteredProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
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
  return GestureDetector(
    onTap: () => _showProductDetails(product),
    child: _buildProductCard(product), // Quitamos el callback
  );
},
          );
        },
      ),

      // Sección del carrito (solo visible si hay productos)
      if (_cartItems.isNotEmpty) ...[
        Divider(thickness: 2),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Tu Carrito',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Carrusel de productos en el carrito
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return Container(
                width: 100,
                margin: EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    // Imagen del producto (ajusta según tu estructura de datos)
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(item['imageUrl'] ?? ''),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(height: 4),
                    // Cantidad
                    Text(
                      '${item['quantity']}x',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Precio
                    Text(
                      '\$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Botón para crear orden
        Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              // Función para crear orden (a implementar)
              // _createOrder();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Colors.blueAccent,
            ),
            child: Text(
              'Crear Orden',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

List<Map<String, dynamic>> _cartItems = [];

void _addToCart(DocumentSnapshot product) {
  final productData = product.data() as Map<String, dynamic>;
  final productId = product.id;
  
  final existingItemIndex = _cartItems.indexWhere((item) => item['id'] == productId);
  
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
    Query query = _firestore.collection('productos');

    if (_selectedCategory != 'Todos') {
      query = query.where('categoria', isEqualTo: _selectedCategory);
    }

    if (_selectedBusiness != 'Todos') {
      query = query.where('negocioId', isEqualTo: _selectedBusiness);
    }

    if (_searchQuery.isNotEmpty) {
      query = query.where('nombre', isGreaterThanOrEqualTo: _searchQuery)
          .where('nombre', isLessThanOrEqualTo: _searchQuery + '\uf8ff');
    }

    return query.snapshots();
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
    final List<String> images = List<String>.from(data['imagenes'] ?? [data['imagen']]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Icon(Icons.error),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                        Text('\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}',
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
                            children: List<Widget>.from(data['tallas'].map((talla) {
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
                            SnackBar(content: Text('Producto agregado al carrito')),
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
              subtitle: Text('\$${data['precio']?.toStringAsFixed(2) ?? '0.00'}'),
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
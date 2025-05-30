import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'store_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialCartItems;

  const FavoritesScreen({
    super.key,
    this.initialCartItems = const [],
  });

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  bool _showCartButton = false;
  List<Map<String, dynamic>> _cartItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    // Inicializar el estado del carrito con los items recibidos
    setState(() {
      _cartItems = widget.initialCartItems;
      _showCartButton = widget.initialCartItems.isNotEmpty;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCartItems(); // Recargar cuando la pantalla se vuelve visible
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartItems();
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesDoc =
          await _firestore.collection('userFavorites').doc(user.uid).get();

      if (userFavoritesDoc.exists) {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          setState(() {
            _favorites = List<Map<String, dynamic>>.from(data['favorites']);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _favorites = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar favoritos: $e');
      setState(() {
        _isLoading = false;
      });
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
          final items = List<Map<String, dynamic>>.from(data['items']);
          if (mounted) {
            setState(() {
              _cartItems = items;
              _showCartButton = items.isNotEmpty;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _cartItems = [];
              _showCartButton = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _cartItems = [];
            _showCartButton = false;
          });
        }
      }
    } catch (e) {
      print('Error al cargar el carrito: $e');
      if (mounted) {
        setState(() {
          _cartItems = [];
          _showCartButton = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(String productId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userFavoritesRef =
          _firestore.collection('userFavorites').doc(user.uid);
      final userFavoritesDoc = await userFavoritesRef.get();

      if (userFavoritesDoc.exists) {
        final data = userFavoritesDoc.data();
        if (data != null && data['favorites'] != null) {
          final List<dynamic> favorites = List.from(data['favorites']);
          favorites.removeWhere((fav) => fav['productId'] == productId);

          await userFavoritesRef.update({
            'favorites': favorites,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _favorites.removeWhere((fav) => fav['productId'] == productId);
          });
        }
      }
    } catch (e) {
      print('Error al eliminar favorito: $e');
    }
  }

  Future<void> _addToCart(Map<String, dynamic> favorite) async {
    if (!mounted) return;

    try {
      print('Objeto favorite completo: $favorite'); // Debug print
      final user = _auth.currentUser;
      if (user == null) return;

      final cartRef = _firestore.collection('userCart').doc(user.uid);
      final cartDoc = await cartRef.get();

      // Obtener los datos del producto del objeto favorite
      final productData = favorite['productData'];
      print('Datos del producto: $productData'); // Debug print

      // Preparar los datos del producto para el carrito
      final cartItem = {
        'id': favorite['productId'],
        'nombre': productData['nombre'] ?? 'Producto sin nombre',
        'precio': productData['precio'] ?? 0.0,
        'imagen': productData['imagen'] ??
            (productData['storeImgs'] != null &&
                    productData['storeImgs'].isNotEmpty
                ? productData['storeImgs'][0]
                : ''),
        'cantidad': 1,
      };

      print('Item a agregar al carrito: $cartItem'); // Debug print

      if (!cartDoc.exists) {
        // Si no existe el carrito, lo creamos
        await cartRef.set({
          'userId': user.uid,
          'items': [cartItem],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _cartItems = [cartItem];
          _showCartButton = true;
        });
      } else {
        // Si existe, actualizamos el array de items
        final data = cartDoc.data();
        if (data != null && data['items'] != null) {
          final List<dynamic> items = List.from(data['items']);

          // Buscar si el producto ya está en el carrito
          final existingIndex =
              items.indexWhere((item) => item['id'] == favorite['productId']);

          if (existingIndex != -1) {
            // Si existe, incrementamos la cantidad
            items[existingIndex]['cantidad'] =
                (items[existingIndex]['cantidad'] ?? 0) + 1;
          } else {
            // Si no existe, lo agregamos
            items.add(cartItem);
          }

          await cartRef.update({
            'items': items,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _cartItems = List<Map<String, dynamic>>.from(items);
            _showCartButton = true;
          });
        }
      }

      if (!mounted) return;

      // Usar un BuildContext fresco para mostrar el SnackBar
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Producto agregado al carrito'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error al agregar al carrito: $e');
      if (!mounted) return;

      // Usar un BuildContext fresco para mostrar el SnackBar de error
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error al agregar al carrito'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildProductImage(Map<String, dynamic> productData) {
    final isDarkMode = Get.isDarkMode;
    final storeImgs = productData['productData']['storeImgs'] as List<dynamic>?;
    final String? imageUrl = productData['productData']['imageUrl'];
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
        fit: BoxFit.cover,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Favoritos'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_favorites.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Favoritos'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No tienes favoritos aún',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Favoritos'),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          final productData = favorite['productData'];

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  child: _buildProductImage(favorite),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12),
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
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.favorite,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      _removeFavorite(favorite['productId']),
                                ),
                                IconButton(
                                  icon: Icon(Icons.shopping_cart,
                                      color: Colors.blue, size: 20),
                                  onPressed: () => _addToCart(favorite),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Disponibles: ${productData['cantidad'] ?? 0}',
                          style: TextStyle(
                            color: productData['cantidad'] > 0
                                ? Colors.black54
                                : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _showCartButton
          ? FloatingActionButton.extended(
              onPressed: () async {
                Navigator.pop(context);
                if (mounted) {
                  _loadCartItems(); // Recargar el estado del carrito
                }
              },
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
}

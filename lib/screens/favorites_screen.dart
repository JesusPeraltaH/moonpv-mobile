import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'store_screen.dart';
import 'package:moonpv/screens/store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonpv/widgets/product_image_widget.dart';
import 'package:moonpv/controllers/cart_controller.dart';
import 'package:moonpv/widgets/cart_bottom_sheet.dart';

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
  final CartController cartController = Get.find();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {}
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
    final productData = favorite['productData'];
    if (productData == null) return; // Ensure product data exists

    print(
        'FavoritesScreen: Adding product to cart: $productData'); // Debug print
    // Pass the original productData to the CartController
    cartController.addToCart(productData);

    // Show the cart bottom sheet
    Get.bottomSheet(
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: CartBottomSheet(),
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      appBar: AppBar(
        title: Text('Favoritos'),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          final productData = favorite['productData'];
          final String productId = favorite['productId'];
          final String productName = productData['nombre'] ?? 'Sin nombre';
          final String productPrice =
              '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}';
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          return Card(
            elevation: 0,
            margin: EdgeInsets.only(bottom: 16),
            color: isDark ? Colors.grey[900] : Colors.white,
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  child: ProductImageWidget(productData: productData),
                ),
                Expanded(
                  child: Container(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Container(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    productName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.favorite,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _removeFavorite(productId),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              productPrice,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: SizedBox(
                                width: 120,
                                child: ElevatedButton(
                                  onPressed: () => _addToCart(favorite),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cartController.cartItems
                                            .any((item) =>
                                                item['id'] == productId)
                                        ? Colors.blue
                                        : Colors.grey[400],
                                    foregroundColor: cartController.cartItems
                                            .any((item) =>
                                                item['id'] == productId)
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    textStyle: TextStyle(fontSize: 12),
                                  ),
                                  child: Text(
                                    'Agregar al Carrito',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Obx(
        () => cartController.showCartButton.value
            ? FloatingActionButton.extended(
                onPressed: () {
                  Get.bottomSheet(
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.75,
                      child: CartBottomSheet(),
                    ),
                    isScrollControlled: true,
                    useRootNavigator: true,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  );
                },
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
            : Container(),
      ),
    );
  }

  double _calculateTotal() {
    return _favorites.fold(0.0, (sum, item) {
      return sum + ((item['precio'] ?? 0.0) * (item['cantidad'] ?? 1));
    });
  }
}

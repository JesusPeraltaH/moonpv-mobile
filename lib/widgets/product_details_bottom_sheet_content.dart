import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:moonpv/controllers/cart_controller.dart';
import 'package:moonpv/widgets/product_image_widget.dart';

class ProductDetailsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String productId;
  final Function(DocumentSnapshot) showProductDetails;

  const ProductDetailsBottomSheetContent({
    Key? key,
    required this.productData,
    required this.productId,
    required this.showProductDetails,
  }) : super(key: key);

  @override
  _ProductDetailsBottomSheetContentState createState() =>
      _ProductDetailsBottomSheetContentState();
}

class _ProductDetailsBottomSheetContentState
    extends State<ProductDetailsBottomSheetContent> {
  List<DocumentSnapshot> _similarProducts = [];
  bool _isLoadingSimilar = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CartController cartController = Get.find();

  @override
  void initState() {
    super.initState();
    _loadSimilarProducts();
  }

  Future<void> _loadSimilarProducts() async {
    setState(() {
      _isLoadingSimilar = true;
    });

    try {
      final productCategories = widget.productData['categoriaId'];
      Query<Map<String, dynamic>> query = _firestore.collection('productos');

      if (productCategories is List) {
        query = query.where('categoriaId', arrayContainsAny: productCategories);
      } else if (productCategories != null) {
        query = query.where('categoriaId', isEqualTo: productCategories);
      }

      final QuerySnapshot snapshot = await query.limit(10).get();

      final List<DocumentSnapshot> similarProducts =
          snapshot.docs.where((doc) => doc.id != widget.productId).toList();

      setState(() {
        _similarProducts = similarProducts;
        _isLoadingSimilar = false;
      });
    } catch (e) {
      print('Error loading similar products: $e');
      setState(() {
        _isLoadingSimilar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.productData;
    final List<String> images =
        List<String>.from(data['imagenes'] ?? [data['imagen'] ?? '']);

    return Container(
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
                      // Variants Section (Placeholder)
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                            elevation: isDark ? 4 : 2,
                            shadowColor: isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.2),
                          ),
                          onPressed: () {
                            final productDataWithId = {
                              ...data,
                              'id': widget.productId,
                            };
                            print('Adding product to cart: $productDataWithId');
                            cartController.addToCart(productDataWithId);
                            Navigator.pop(context);
                          },
                          child: Text('AGREGAR AL CARRITO',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Similar Products Section
                      Text(
                        'Productos Similares',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: 12),
                      _isLoadingSimilar
                          ? Center(child: CircularProgressIndicator())
                          : _similarProducts.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay productos similares',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 220,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _similarProducts.length,
                                    itemBuilder: (context, index) {
                                      final similarProduct =
                                          _similarProducts[index];
                                      final similarProductData = similarProduct
                                          .data() as Map<String, dynamic>;

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          widget.showProductDetails(
                                              similarProduct);
                                        },
                                        child: Container(
                                          width: 150,
                                          margin: EdgeInsets.only(right: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: ProductImageWidget(
                                                        productData:
                                                            similarProductData)),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                similarProductData['nombre'] ??
                                                    'Sin nombre',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                '\$${similarProductData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../controllers/cart_controller.dart';

class CartBottomSheet extends StatelessWidget {
  final CartController cartController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.white,
      child: Stack(
        children: [
          Column(
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
                'Carrito',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              // Use Obx to react to changes in the observable list
              Obx(() => Expanded(
                    child: ListView.builder(
                      itemCount: cartController.cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartController.cartItems[index];
                        return ListTile(
                          key: ValueKey(item['id']),
                          leading: item['imagen'] != null &&
                                  item['imagen'].isNotEmpty
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
                                  // Decrement quantity or remove item if quantity is 1
                                  cartController
                                      .removeFromCart(item['id'].toString());
                                },
                              ),
                              Text('${item['cantidad']}'),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  cartController
                                      .addToCart(item); // Pass the item data
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )),
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
                    Obx(() => Text(
                          '\$${cartController.calculateTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        )),
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
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: () => Get.back(),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class CartController extends GetxController {
  // Observable list for cart items
  var cartItems = <Map<String, dynamic>>[].obs;
  // Observable boolean to control visibility of the floating cart button
  var showCartButton = false.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void onInit() {
    super.onInit();
    loadCartItems(); // Load cart items when the controller is initialized
  }

  // Add a product to the cart or increment its quantity if already exists
  void addToCart(Map<String, dynamic> product) {
    final String productId = product['id'] ?? '';
    // 1. Get available quantity from the database data
    final int availableQuantity = (product['cantidad'] ?? 0).toInt();

    // Find the product in the current cart items
    final existingIndex =
        cartItems.indexWhere((item) => item['id'] == productId);

    int currentCartQuantity = 0;
    if (existingIndex != -1) {
      currentCartQuantity = (cartItems[existingIndex]['cantidad'] ?? 0).toInt();
    }

    // Calculate the quantity IF we add one more
    int requestedTotalQuantity = currentCartQuantity + 1;

    // Check if adding one more exceeds the available quantity of THIS PRODUCT
    if (requestedTotalQuantity > availableQuantity) {
      // Prevent adding and show alert
      String message;
      if (availableQuantity == 0) {
        message = 'Este producto no está disponible en este momento.';
      } else {
        // Message is clearer about the stock of this specific item
        message =
            'Solo hay $availableQuantity unidades disponibles de este producto.';
      }

      Get.snackbar(
        'Sin Stock Suficiente',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange, // Use a warning color
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return; // Stop the process
    }

    // If the check passed, proceed with adding/incrementing
    if (existingIndex != -1) {
      cartItems[existingIndex]['cantidad']++;
    } else {
      final cartItem = {
        'id': productId, // Use productId here for consistency
        'nombre': product['nombre'] ?? 'Producto sin nombre',
        'precio': product['precio'] ?? 0.0,
        'imagen':
            product['imagen'] ?? '', // Assuming 'imagen' or 'storeImgs' exists
        'cantidad': 1,
      };
      cartItems.add(cartItem);
    }
    // Show the cart button if items are added
    showCartButton.value = cartItems.isNotEmpty;
    _saveCartItems(); // Save cart state to Firestore
  }

  // Remove a product from the cart or decrement its quantity
  void removeFromCart(String productId) {
    final existingIndex =
        cartItems.indexWhere((item) => item['id'] == productId);

    if (existingIndex != -1) {
      if (cartItems[existingIndex]['cantidad'] > 1) {
        cartItems[existingIndex]['cantidad']--;
      } else {
        cartItems.removeAt(existingIndex);
      }
    }
    showCartButton.value = cartItems.isNotEmpty;
    _saveCartItems(); // Save cart state to Firestore
  }

  // Remove a product from the cart or decrement its quantity
  void deleteItemFromCart(String productId) {
    print(
        'CartController: Deleting item with productId: $productId'); // Debug print
    cartItems.removeWhere((item) => item['id'] == productId);
    showCartButton.value = cartItems.isNotEmpty;
    _saveCartItems(); // Save cart state to Firestore
  }

  // Calculate the total price of items in the cart
  double calculateTotal() {
    return cartItems.fold(0.0, (sum, item) {
      return sum + ((item['precio'] ?? 0.0) * (item['cantidad'] ?? 1));
    });
  }

  // Load cart items from Firestore
  Future<void> loadCartItems() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        cartItems.clear();
        showCartButton.value = false;
        return;
      }

      final cartDoc =
          await _firestore.collection('userCart').doc(user.uid).get();

      if (cartDoc.exists) {
        final data = cartDoc.data();
        if (data != null && data['items'] != null) {
          final List<dynamic> loadedItems = data['items'];
          // Update the observable list directly
          cartItems.assignAll(loadedItems
              .map((item) => Map<String, dynamic>.from(item))
              .toList());
          showCartButton.value = cartItems.isNotEmpty;
        } else {
          cartItems.clear();
          showCartButton.value = false;
        }
      } else {
        cartItems.clear();
        showCartButton.value = false;
      }
    } catch (e) {
      print('Error al cargar el carrito: $e');
      cartItems.clear();
      showCartButton.value = false;
    }
  }

  // Save cart items to Firestore
  Future<void> _saveCartItems() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return; // Cannot save if user is not logged in

      await _firestore.collection('userCart').doc(user.uid).set(
          {
            'items': cartItems.toList(), // Convert RxList to List
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(
              merge: true)); // Use merge to avoid overwriting other fields
    } catch (e) {
      print('Error al guardar el carrito: $e');
    }
  }

  // Clear the cart (e.g., after checkout or logout)
  void clearCart() {
    cartItems.clear();
    showCartButton.value = false;
    _saveCartItems(); // Clear cart in Firestore as well
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonpv/screens/login_screen.dart';

class StoreScreen extends StatelessWidget {
  // Lista de productos de ejemplo
  final List<Map<String, dynamic>> products = [
    {
      "id": 1,
      "name": "Zapatos Deportivos",
      "price": 59.99,
      "image": "https://via.placeholder.com/150",
    },
    {
      "id": 2,
      "name": "Camiseta Casual",
      "price": 19.99,
      "image": "https://via.placeholder.com/150",
    },
    {
      "id": 3,
      "name": "Reloj Inteligente",
      "price": 129.99,
      "image": "https://via.placeholder.com/150",
    },
    {
      "id": 4,
      "name": "Mochila Impermeable",
      "price": 39.99,
      "image": "https://via.placeholder.com/150",
    },
    {
      "id": 5,
      "name": "Audífonos Inalámbricos",
      "price": 89.99,
      "image": "https://via.placeholder.com/150",
    },
    {
      "id": 6,
      "name": "Gafas de Sol",
      "price": 29.99,
      "image": "https://via.placeholder.com/150",
    },
  ];

  // 🔹 Función para cerrar sesión
  void _logout(BuildContext context) async {
    // Mostrar un diálogo de confirmación
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar el diálogo
                try {
                  await FirebaseAuth.instance.signOut(); // Cerrar sesión

                  // Eliminar estado de autenticación guardado
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('isLoggedIn');
                    await prefs.remove('userId');
                  } catch (e) {
                    print("Error al eliminar preferencias: $e");
                  }

                  // Navegar a pantalla de login
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
              child: const Text('Cerrar sesión',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Catálogo de Tienda"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.shopping_cart),
            onSelected: (value) {
              if (value == 'cart') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Carrito de compras")),
                );
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'cart',
                child: Text('Ver Carrito'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(product: product);
          },
        ),
      ),
    );
  }
}

// Widget para mostrar la tarjeta de cada producto
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: Image.network(
              product["image"],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported,
                    size: 50, color: Colors.grey);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product["name"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "\$${product["price"].toString()}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  child: const Text("Ver Detalles"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla de detalles del producto
class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Detalles del Producto")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              product["image"],
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported,
                    size: 100, color: Colors.grey);
              },
            ),
            const SizedBox(height: 20),
            Text(
              product["name"],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "\$${product["price"].toString()}",
              style: const TextStyle(
                fontSize: 20,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Descripción del producto: Lorem ipsum dolor sit amet...",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Producto agregado al carrito")),
                  );
                },
                child: const Text("Agregar al Carrito"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

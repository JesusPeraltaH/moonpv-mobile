import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Catálogo de Tienda"),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              // Navegar al carrito de compras (puedes implementarlo más adelante)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Carrito de compras")),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Dos columnas
          crossAxisSpacing: 10, // Espacio entre columnas
          mainAxisSpacing: 10, // Espacio entre filas
          childAspectRatio: 0.75, // Relación de aspecto de los elementos
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(product: product);
        },
      ),
    );
  }
}

// Widget para mostrar la tarjeta de cada producto
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.network(
              product["image"],
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product["name"],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "\$${product["price"].toString()}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    // Navegar a la pantalla de detalles del producto
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  child: Text("Ver Detalles"),
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

  const ProductDetailScreen({required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Detalles del Producto"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              product["image"],
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 20),
            Text(
              product["name"],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "\$${product["price"].toString()}",
              style: TextStyle(
                fontSize: 20,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Descripción del producto: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Acción para agregar al carrito
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Producto agregado al carrito")),
                  );
                },
                child: Text("Agregar al Carrito"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

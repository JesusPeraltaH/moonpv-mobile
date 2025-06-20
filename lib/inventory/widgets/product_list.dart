import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onProductTap;
  final Function(String) onDeleteProduct;
  final bool isDark;

  const ProductList({
    Key? key,
    required this.products,
    required this.onProductTap,
    required this.onDeleteProduct,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: product['imagen'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      product['imagen'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: Icon(Icons.image_not_supported),
                  ),
            title: Text(
              product['nombre'] ?? 'Sin nombre',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código: ${product['codigo'] ?? 'N/A'}'),
                Text(
                    'Precio: \$${product['precio']?.toStringAsFixed(2) ?? '0.00'}'),
                Text('Cantidad: ${product['cantidad'] ?? '0'}'),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDeleteProduct(product['id']),
            ),
            onTap: () => onProductTap(product),
          ),
        );
      },
    );
  }
}

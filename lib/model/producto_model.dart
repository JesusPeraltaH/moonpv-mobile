import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String nombre;
  final int cantidad;
  final String categoriaId;

  Product({
    required this.id,
    required this.nombre,
    required this.cantidad,
    required this.categoriaId,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Product(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      cantidad: data['cantidad'] ?? 0,
      categoriaId: data['categoriaId'] ?? '',
    );
  }
}
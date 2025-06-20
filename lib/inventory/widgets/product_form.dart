import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ProductForm extends StatefulWidget {
  final List<Map<String, dynamic>> productControllers;
  final Function(int, {bool isMainImage}) onPickImage;
  final Function(int) onAddProduct;
  final Function(int) onRemoveProduct;
  final int? editingIndex;

  const ProductForm({
    Key? key,
    required this.productControllers,
    required this.onPickImage,
    required this.onAddProduct,
    required this.onRemoveProduct,
    this.editingIndex,
  }) : super(key: key);

  @override
  _ProductFormState createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.productControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controllers = entry.value;
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Producto ${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.productControllers.length > 1)
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => widget.onRemoveProduct(index),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: controllers['codigo'],
                    decoration: InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: controllers['nombre'],
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: controllers['precio'],
                    decoration: InputDecoration(
                      labelText: 'Precio',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: controllers['cantidad'],
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onPickImage(index),
                          icon: Icon(Icons.image),
                          label: Text('Imagen Principal'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              widget.onPickImage(index, isMainImage: false),
                          icon: Icon(Icons.photo_library),
                          label: Text('Imágenes Adicionales'),
                        ),
                      ),
                    ],
                  ),
                  if (controllers['imagen'] != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Image.file(
                        controllers['imagen'],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () =>
              widget.onAddProduct(widget.productControllers.length),
          icon: Icon(Icons.add),
          label: Text('Agregar Producto'),
        ),
      ],
    );
  }
}

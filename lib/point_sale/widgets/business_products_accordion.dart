import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessProductsAccordion extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductSelected;

  const BusinessProductsAccordion({
    Key? key,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  _BusinessProductsAccordionState createState() =>
      _BusinessProductsAccordionState();
}

class _BusinessProductsAccordionState extends State<BusinessProductsAccordion> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedBusinesses = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('negocios').snapshots(),
      builder: (context, businessSnapshot) {
        if (businessSnapshot.hasError) {
          return Center(child: Text('Error al cargar negocios'));
        }

        if (!businessSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: businessSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final business = businessSnapshot.data!.docs[index];
            final businessId = business.id;
            final businessData = business.data() as Map<String, dynamic>;

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                key: Key(businessId),
                initiallyExpanded: _expandedBusinesses[businessId] ?? false,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedBusinesses[businessId] = expanded;
                  });
                },
                title: Text(
                  businessData['nombreEmpresa'] ?? 'Negocio sin nombre',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  businessData['categoria'] ?? 'Sin categoría',
                  style: TextStyle(fontSize: 14),
                ),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('productos')
                        .where('negocioId', isEqualTo: businessId)
                        .snapshots(),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.hasError) {
                        return Center(child: Text('Error al cargar productos'));
                      }

                      if (!productSnapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: productSnapshot.data!.docs.length,
                        itemBuilder: (context, productIndex) {
                          final product =
                              productSnapshot.data!.docs[productIndex];
                          final productData =
                              product.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: productData['imagen'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      productData['imagen'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[300],
                                          child:
                                              Icon(Icons.image_not_supported),
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
                            title: Text(productData['nombre'] ?? 'Sin nombre'),
                            subtitle: Text(
                              '\$${productData['precio']?.toStringAsFixed(2) ?? '0.00'}',
                            ),
                            trailing: Text(
                              'Stock: ${productData['cantidad'] ?? '0'}',
                              style: TextStyle(
                                color: ((productData['cantidad'] as num?)
                                                ?.toInt() ??
                                            0) >
                                        0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            onTap: () {
                              print('Producto seleccionado: ${productData}');
                              widget.onProductSelected({
                                'codigo': productData['codigo'] ?? '',
                                'nombre': productData['nombre'] ?? '',
                                'precio': productData['precio'] ?? 0.0,
                                'cantidad': 1,
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

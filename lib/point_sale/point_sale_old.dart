import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PointSale extends StatefulWidget {
  const PointSale({super.key});

  @override
  State<PointSale> createState() => _SalespointPageState();
}

class _SalespointPageState extends State<PointSale> {
  TextEditingController controller = TextEditingController();
  String text = '';

  Future<List<Widget>> _searchProducts(String query) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('index', arrayContains: query.toLowerCase())
        .get();

    List<Widget> list = [];
    for (var doc in snapshot.docs) {
      List imageUrls = doc['imageUrls'] ?? [];
      String firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';

      list.add(Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: firstImageUrl.isEmpty
                          ? const AssetImage('assets/images/default.png')
                          : NetworkImage(firstImageUrl) as ImageProvider,
                      child: firstImageUrl.isEmpty
                          ? const Icon(Icons.face_rounded)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['name'] ?? 'Nombre no disponible',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            doc['description'] ?? 'Sin descripción',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                          ),
                          Text(
                            'Cantidad: ${doc['quantity'] ?? 'No disponible'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Código: ${doc['code'] ?? 'Sin código'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        String productCode = doc['code'] ?? '';
                        // Aquí puedes manejar la navegación o lógica necesaria
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 60),
            child: Divider(thickness: 1, height: 1),
          ),
        ],
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                hintText: 'Busca productos',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.cancel_rounded),
                  onPressed: () {
                    setState(() {
                      controller.clear();
                      text = '';
                    });
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  text = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Widget>>(
              future: _searchProducts(text),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.data!.isEmpty) {
                  return Center(
                    child: Text('No products found.'),
                  );
                }

                return ListView(
                  children: snapshot.data!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

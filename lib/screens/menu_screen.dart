import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moonpv/inventory/sales.dart';
import 'package:moonpv/point_sale/point_sale.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/business_owner_screen.dart';
import 'package:moonpv/screens/store_screen.dart';

class MenuScreen extends StatelessWidget {
  final String role;

  MenuScreen({required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Menú Principal")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (role == "admin")
              ElevatedButton(
                onPressed: () {
                  Get.to(() =>
                      SalespointNewSalePage()); // Redirige a la pantalla de admin
                },
                child: Text("Acceso a Punto de Venta"),
              ),
            if (role == "business_owner")
              ElevatedButton(
                onPressed: () {
                  Get.to(() =>
                      BusinessOwnerScreen()); // Redirige a la pantalla de jefe de negocio
                },
                child: Text("Gestión de Negocio"),
              ),
            if (role == "user")
              ElevatedButton(
                onPressed: () {
                  Get.to(
                      () => StoreScreen()); // Redirige a la pantalla de usuario
                },
                child: Text("Ver Catálogo de Tienda"),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moonpv/inventory/apartadosList.dart';
import 'package:moonpv/inventory/sales.dart';
import 'package:moonpv/inventory/salesList.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/add_user_screen.dart';
import 'package:moonpv/screens/conteo.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/screens/payment_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ajustes_screen.dart';
import 'inventory_page.dart';

class MainDrawer extends StatelessWidget {
  final Function(BuildContext)?
      logoutCallback; // Callback para la función de logout

  const MainDrawer({Key? key, this.logoutCallback}) : super(key: key);

  void _logout(BuildContext context) async {
    // Mostrar un diálogo de confirmación
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Cerrar sesión'),
          content: Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar el diálogo
                try {
                  await FirebaseAuth.instance
                      .signOut(); // Cerrar sesión en Firebase

                  // Eliminar el estado de autenticación guardado en SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn');
                  await prefs.remove('userId');

                  Get.offAll(() =>
                      LoginScreen()); // Navegar a la pantalla de inicio de sesión
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e')),
                  );
                }
              },
              child: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Opciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Página Principal'),
            onTap: () {
              Get.to(SalespointNewSalePage());
            },
          ),
          ListTile(
            leading: Icon(Icons.sell),
            title: Text('Bitacora Ventas'),
            onTap: () {
              Get.to(SalesListScreen());
            },
          ),
          ListTile(
            leading: Icon(Icons.person_search_outlined),
            title: Text('Ventas por Negocio'),
            onTap: () {
              Get.to(SalesPage());
            },
          ),
          ListTile(
            leading: Icon(Icons.shopping_cart_checkout_rounded),
            title: Text('Apartados'),
            onTap: () {
              Get.to(ApartadosListScreen());
            },
          ),
          const ListTile(
            leading: Icon(Icons.admin_panel_settings),
            title: Text('Admin'),
            onTap: null, // No hace nada, solo es un título
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inventario'),
              onTap: () {
                Get.to(() => InventoryPage());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Ajustes'),
              onTap: () {
                Get.to(AjustesScreen());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Crear Usuarios'),
              onTap: () {
                Get.to(CreateUserScreen());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Pago Mensual'),
              onTap: () {
                Get.to(PaymentManagementScreen());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Conteo'),
              onTap: () {
                Get.to(ConteoNegociosScreen(negociosSeleccionados: []));
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {}, // TODO: Implementar navegación
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              _logout(context);
            },
          ),
        ],
      ),
    );
  }
}

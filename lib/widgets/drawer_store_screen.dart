import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moonpv/screens/favorites_screen.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/settings/user_settings_screen.dart';
import 'package:moonpv/screens/store_screen.dart';

class DrawerStoreScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPedidosTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  const DrawerStoreScreen({
    Key? key,
    required this.isDark,
    required this.onPedidosTap,
    required this.onFavoritesTap,
    required this.onSettingsTap,
    required this.onLogoutTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.grey.shade200,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (ModalRoute.of(context)?.settings.name != '/store') {
                      Get.to(() => StoreScreen());
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/moon_solo_blanco_recortada.png'
                          : 'assets/images/moon_solo_negro_recortada.png',
                      height: 60,
                    ),
                  ),
                ),
                //SizedBox(height: 40),
                // Text(
                //   'MoonConcept',
                //   style: TextStyle(
                //       color: isDark ? Colors.white : Colors.black,
                //       fontSize: 18,
                //       fontWeight: FontWeight.bold),
                // ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Pedidos'),
            onTap: onPedidosTap,
          ),
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text('Favoritos'),
            onTap: onFavoritesTap,
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Configuración'),
            onTap: onSettingsTap,
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            onTap: onLogoutTap,
          ),
        ],
      ),
    );
  }
}

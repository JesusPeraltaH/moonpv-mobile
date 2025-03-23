import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/business_owner_screen.dart';
import 'package:moonpv/screens/store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Importa tu pantalla de login

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
          future: _checkLoginStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator(); // Muestra un indicador de carga
            } else {
              return SizedBox.shrink(); // No muestra nada mientras redirige
            }
          },
        ),
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn) {
        final String userId = prefs.getString('userId') ?? '';
        final String userRole = prefs.getString('userRole') ?? '';

        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final String role = userDoc['role'];

          if (role == "Admin") {
            Get.off(() => SalespointNewSalePage());
          } else if (role == "Dueño de Negocio") {
            Get.off(() => BusinessOwnerScreen());
          } else if (role == "Empleado") {
            Get.off(() =>
                SalespointNewSalePage()); // Redirigir a la pantalla de empleado
          } else {
            Get.off(() => StoreScreen()); // Redirigir a la pantalla por defecto
          }
        } else {
          await _logout(); // Cerrar sesión si el usuario no existe en Firestore
          Get.off(() => LoginScreen()); // Redirigir al login
        }
      } else {
        Get.off(
            () => LoginScreen()); // Redirigir al login si no está autenticado
      }
    } catch (e) {
      print('Error al verificar el estado de autenticación: $e');
      await _logout(); // Cerrar sesión en caso de error
      Get.off(() => LoginScreen()); // Redirigir al login
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn'); // Eliminar el estado de autenticación
      await prefs.remove('userId'); // Eliminar el ID del usuario
      await prefs.remove('userRole'); // Eliminar el rol del usuario

      // Cerrar sesión en Firebase
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }
}

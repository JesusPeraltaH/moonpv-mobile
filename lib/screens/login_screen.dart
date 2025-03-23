import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart'; // Pantalla de Admin
import 'package:moonpv/screens/business_owner_screen.dart'; // Pantalla de Dueño de Negocio
import 'package:moonpv/screens/store_screen.dart'; // Pantalla de Usuario Normal
import 'package:moonpv/services/app_images.dart';
import 'package:moonpv/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Servicio de autenticación con Google

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    // Estado para controlar la visibilidad de la contraseña
    bool _obscurePassword = true;

    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Correo"),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword; // Alternar visibilidad
                        });
                      },
                    ),
                  ),
                  obscureText:
                      _obscurePassword, // Controlar visibilidad de la contraseña
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _login(context);
              },
              child: Text("Iniciar Sesión"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final credenciales = await AuthService().signInWithGoogle();
                  debugPrint(credenciales.user?.displayName);
                  debugPrint(credenciales.user?.photoURL);
                  debugPrint(credenciales.user?.email);
                  Get.off(() => StoreScreen());
                } catch (e) {
                  Get.snackbar(
                    "Error",
                    "No se pudo iniciar sesión con Google: $e",
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  await _logout(); // Cerrar sesión en caso de error
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppImages.google,
                    height: 24,
                  ),
                  SizedBox(width: 10),
                  Text("Iniciar sesión con Google"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context) async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        "Error",
        "Por favor, ingresa tu correo y contraseña",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'isLoggedIn', true); // Guardar estado de autenticación
      await prefs.setString(
          'userId', userCredential.user!.uid); // Guardar ID del usuario

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (userDoc.exists) {
        final String role = userDoc['role'];
        await prefs.setString('userRole', role); // Guardar el rol del usuario

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
        Get.off(() => StoreScreen()); // Redirigir a la pantalla por defecto
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "No se pudo iniciar sesión: $e",
        snackPosition: SnackPosition.BOTTOM,
      );
      await _logout(); // Cerrar sesión en caso de error
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

      // Redirigir a la pantalla de login
      Get.off(() => LoginScreen());
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  Future<void> _checkLoginStatus(BuildContext context) async {
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
      }
    } catch (e) {
      print('Error al verificar el estado de autenticación: $e');
      await _logout(); // Cerrar sesión en caso de error
      Get.off(() => LoginScreen()); // Redirigir al login
    }
  }
}

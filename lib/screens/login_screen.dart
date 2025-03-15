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

  // Referencia a Firebase Auth y Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para iniciar sesión

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
      // Iniciar sesión con Firebase Authentication
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardar el estado de autenticación en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'isLoggedIn', true); // Guardar estado de autenticación
      await prefs.setString(
          'userId', userCredential.user!.uid); // Guardar ID del usuario

      // Verificar si el usuario existe en Firestore
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (userDoc.exists) {
        // Obtener el rol del usuario
        final String role = userDoc['role'];

        // Redirigir según el rol
        if (role == "Admin") {
          Get.off(() => SalespointNewSalePage()); // Pantalla de Admin
        } else if (role == "Dueño de Negocio") {
          Get.off(() => BusinessOwnerScreen()); // Pantalla de Dueño de Negocio
        } else {
          Get.off(() => StoreScreen()); // Pantalla de Usuario Normal
        }
      } else {
        // Si el usuario no está en la colección `users`, es un usuario normal
        Get.off(() => StoreScreen()); // Pantalla de Usuario Normal
      }
    } catch (e) {
      // Manejar errores de autenticación
      Get.snackbar(
        "Error",
        "No se pudo iniciar sesión: $e",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn'); // Eliminar el estado de autenticación
    await prefs.remove('userId'); // Eliminar el ID del usuario

    // Cerrar sesión en Firebase
    await FirebaseAuth.instance.signOut();

    // Redirigir a la pantalla de login
    Get.off(() => LoginScreen());
  }

  Future<void> _checkLoginStatus(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn) {
        // Obtener el ID del usuario guardado
        final String userId = prefs.getString('userId') ?? '';

        // Verificar si el usuario existe en Firestore
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          // Obtener el rol del usuario
          final String role = userDoc['role'];

          // Redirigir según el rol
          if (role == "Admin") {
            Get.off(() => SalespointNewSalePage()); // Pantalla de Admin
          } else if (role == "Dueño de Negocio") {
            Get.off(
                () => BusinessOwnerScreen()); // Pantalla de Dueño de Negocio
          } else {
            Get.off(() => StoreScreen()); // Pantalla de Usuario Normal
          }
        } else {
          // Si el usuario no está en la colección `users`, redirigir a la pantalla de usuario normal
          Get.off(() => StoreScreen());
        }
      }
    } catch (e) {
      print('Error al verificar el estado de autenticación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar el estado de autenticación al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus(context);
    });

    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo para el correo
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Correo"),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),

            // Campo para la contraseña
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            SizedBox(height: 20),

            // Botón para iniciar sesión
            ElevatedButton(
              onPressed: () async {
                await _login(context);
              },
              child: Text("Iniciar Sesión"),
            ),
            SizedBox(height: 20),

            // Botón para iniciar sesión con Google
            ElevatedButton(
              onPressed: () async {
                try {
                  final credenciales = await AuthService().signInWithGoogle();
                  debugPrint(credenciales.user?.displayName);
                  debugPrint(credenciales.user?.photoURL);
                  debugPrint(credenciales.user?.email);

                  // Redirigir a la pantalla después de la autenticación
                  Get.off(() => StoreScreen());
                } catch (e) {
                  Get.snackbar(
                    "Error",
                    "No se pudo iniciar sesión con Google: $e",
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white, // Texto negro
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
}

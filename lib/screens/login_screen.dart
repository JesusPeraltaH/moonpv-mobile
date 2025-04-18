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

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false; // Estado de carga
  bool _obscurePassword = true; // Control de visibilidad de la contraseña
  

  @override
Widget build(BuildContext context) {
  // Determinar el color de los íconos según el tema
  Color iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
final isDark = Theme.of(context).brightness == Brightness.dark;
  return Scaffold(
    // appBar: AppBar(
    //   title: Text("Login", style: TextStyle(color: Colors.white)),
    //   backgroundColor: Theme.of(context).colorScheme.primary,
    // ),
    body: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
        isDark ? 'assets/images/moon_blanco.png' : 'assets/images/moon_negro.png',
        height: 200,
      ),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Correo",
              prefixIcon: Icon(Icons.email, color: iconColor),  // Cambiar color del ícono
            ),
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: iconColor),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: "Contraseña",
              prefixIcon: Icon(Icons.lock, color: iconColor),  // Cambiar color del ícono
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: iconColor,  // Cambiar color del ícono
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
            style: TextStyle(color: iconColor),
          ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                await _login(context);
                setState(() => _isLoading = false);
              },
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Iniciar Sesión"),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                await _loginWithGoogle();
                setState(() => _isLoading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
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
      Get.snackbar("Error", "Por favor, ingresa tu correo y contraseña",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(email: email, password: password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userCredential.user!.uid);

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      await Future.delayed(Duration(seconds: 2)); // Simulación de carga visible

      if (userDoc.exists) {
        final String role = userDoc['role'];
        await prefs.setString('userRole', role);

        if (role == "Admin") {
          Get.off(() => SalespointNewSalePage());
        } else if (role == "Dueño de Negocio") {
          Get.off(() => BusinessOwnerScreen());
        } else if (role == "Empleado") {
          Get.off(() => SalespointNewSalePage());
        } else {
          Get.off(() => StoreScreen());
        }
      } else {
        Get.off(() => StoreScreen());
      }
    } catch (e) {
      Get.snackbar("Error", "No se pudo iniciar sesión: $e",
          snackPosition: SnackPosition.BOTTOM);
      await _logout();
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final credenciales = await AuthService().signInWithGoogle();
      debugPrint(credenciales.user?.displayName);
      debugPrint(credenciales.user?.photoURL);
      debugPrint(credenciales.user?.email);

      await Future.delayed(Duration(seconds: 2)); // Simulación de carga visible
      Get.off(() => StoreScreen());
    } catch (e) {
      Get.snackbar("Error", "No se pudo iniciar sesión con Google: $e",
          snackPosition: SnackPosition.BOTTOM);
      await _logout();
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userId');
      await prefs.remove('userRole');
      await FirebaseAuth.instance.signOut();
      Get.off(() => LoginScreen());
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }
}

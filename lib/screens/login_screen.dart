import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart'; // Pantalla de Admin
import 'package:moonpv/screens/business_owner_screen.dart'; // Pantalla de Dueño de Negocio
import 'package:moonpv/screens/sign_up.dart';
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
  
void _showCreateAccountBottomSheet(BuildContext context) {
    Get.bottomSheet(
      CreateAccountBottomSheet(),
      isScrollControlled: true, 
      backgroundColor: Colors.white, // <- Muy importante para opacidad
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),// Permite que el bottom sheet sea más alto
    );
  }
  
  @override
Widget build(BuildContext context) {
  final iconColor = Theme.of(context).brightness == Brightness.dark 
      ? Colors.white 
      : Colors.black;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Scaffold(
    body: Stack(
      children: [
        // Contenido principal centrado
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  isDark ? 'assets/images/moon_blanco.png' : 'assets/images/moon_negro.png',
                  height: 200,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Correo",
                    prefixIcon: Icon(Icons.email, color: iconColor),
                 
                ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: Icon(Icons.lock, color: iconColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: iconColor,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  style: TextStyle(color: iconColor),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showCreateAccountBottomSheet(context),
                      child: Text(
                        "Olvidé mi contraseña",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      await _login(context);
                      setState(() => _isLoading = false);
                    },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Iniciar Sesión"),
                  ),
                ),
                const SizedBox(height: 16),
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
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                AppImages.google,
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text("Iniciar sesión con Google"),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sección "Aún no tienes cuenta" fija en la parte inferior
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("¿Aún no tienes cuenta?"),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showCreateAccountBottomSheet(context),
                child: Text(
                  "Crear cuenta",
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  

 Future<void> _login(BuildContext context) async {
  final String email = _emailController.text.trim();
  final String password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    _showSnackbar("Error", "Por favor, ingresa tu correo y contraseña", Colors.red);
    return;
  }

  try {
    final UserCredential userCredential =
        await _auth.signInWithEmailAndPassword(email: email, password: password);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', userCredential.user!.uid);

    final DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userCredential.user?.uid).get();

    _showSnackbar("Bienvenido", "Inicio de sesión exitoso", Colors.green);

    await Future.delayed(Duration(seconds: 2));

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
  } on FirebaseAuthException catch (e) {
    String errorMessage = "Ocurrió un error al iniciar sesión.";

    if (e.code == 'user-not-found') {
      errorMessage = "No existe una cuenta con ese correo.";
    } else if (e.code == 'wrong-password') {
      errorMessage = "La contraseña es incorrecta.";
    } else if (e.code == 'invalid-email') {
      errorMessage = "El correo ingresado no es válido.";
    }

    _showSnackbar("Error", errorMessage, Colors.red);
    await _logout();
  } catch (e) {
    _showSnackbar("Error", "Error inesperado al iniciar sesión.", Colors.red);
    await _logout();
  }
}

void _showSnackbar(String title, String message, Color color) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.TOP,
    backgroundColor: color,
    colorText: Colors.white,
    margin: EdgeInsets.all(10),
  );
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

import 'dart:async';
import 'dart:io';

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
import 'package:moonpv/widgets/phone_login_bottom_sheet.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showCreateAccountBottomSheet(BuildContext context) {
    Get.bottomSheet(
      CreateAccountBottomSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.white, // <- Muy importante para opacidad
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ), // Permite que el bottom sheet sea más alto
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : null, // Fondo negro en oscuro, por defecto (blanco) en claro
      body: Stack(
        children: [
          // Contenido principal centrado
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        isDark
                            ? 'assets/images/moon_blanco.png'
                            : 'assets/images/moon_negro.png',
                        height: 200,
                      ),
                      const SizedBox(height: 32),
                      // Email TextField
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black
                              : Colors
                                  .white, // Fondo del contenedor según el tema
                          borderRadius: BorderRadius.circular(
                              8), // Radio similar al buscador
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black
                                      .withOpacity(0.1), // Sombra según el tema
                              blurRadius: 4.0,
                              spreadRadius: 1.0,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                              prefixIcon: Icon(Icons.email, color: iconColor),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              labelText: "Correo",
                              labelStyle: TextStyle(color: iconColor)),
                          style: TextStyle(color: iconColor),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu correo electrónico';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Password TextField
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black
                              : Colors
                                  .white, // Fondo del contenedor según el tema
                          borderRadius: BorderRadius.circular(
                              8), // Radio similar al buscador
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black
                                      .withOpacity(0.1), // Sombra según el tema
                              blurRadius: 4.0,
                              spreadRadius: 1.0,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                              prefixIcon: Icon(Icons.lock, color: iconColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: iconColor,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              labelText: "Contraseña",
                              labelStyle: TextStyle(color: iconColor)),
                          obscureText: _obscurePassword,
                          style: TextStyle(color: iconColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu contraseña';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _showCreateAccountBottomSheet(context),
                            child: Text(
                              "Olvidé mi contraseña",
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : Theme.of(context).primaryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _isLoading = true);
                                    await _login(context);
                                    setState(() => _isLoading = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              foregroundColor:
                                  isDark ? Colors.white : Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              elevation: isDark ? 4 : 2,
                              shadowColor: isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.2)),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("Iniciar Sesión"),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Botón para iniciar sesión con teléfono
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => PhoneLoginBottomSheet(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                isDark ? Colors.white : Colors.black,
                            foregroundColor:
                                isDark ? Colors.black : Colors.white,
                          ),
                          child: Text('INICIAR SESIÓN CON TELÉFONO'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  try {
                                    setState(() => _isLoading = true);

                                    await _loginWithGoogle();

                                    // El éxito se maneja dentro de _loginWithGoogle con Get.off()
                                    // No necesitamos más lógica aquí
                                  } on FirebaseAuthException catch (e) {
                                    setState(() => _isLoading = false);

                                    // Mostrar error específico (ya traducido desde auth_service)
                                    Get.snackbar(
                                      'Error',
                                      e.message ?? 'Error al iniciar sesión',
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.red[600],
                                      colorText: Colors.white,
                                      duration: Duration(seconds: 4),
                                    );
                                  } catch (e) {
                                    setState(() => _isLoading = false);

                                    // Error genérico
                                    Get.snackbar(
                                      'Error',
                                      'Ocurrió un error inesperado',
                                      snackPosition: SnackPosition.TOP,
                                      backgroundColor: Colors.red[600],
                                      colorText: Colors.white,
                                      duration: Duration(seconds: 4),
                                    );

                                    // Registrar error completo en consola
                                    debugPrint('Error en login Google: $e');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.grey[900] : Colors.white,
                            foregroundColor:
                                isDark ? Colors.white : Colors.black,
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
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
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Theme.of(context).primaryColor),
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
      _showSnackbar(
          "Error", "Por favor, ingresa tu correo y contraseña", Colors.red);
      return;
    }

    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      _showSnackbar("Bienvenido", "Inicio de sesión exitoso", Colors.green);

      await Future.delayed(Duration(seconds: 2));

      if (userDoc.exists) {
        final String role = userDoc['role'];
        final prefs = await SharedPreferences.getInstance();
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
      } else if (e.code == 'channel-error') {
        errorMessage = "Asegúrate de que todos los campos estén llenos.";
      }

      _showSnackbar("Error", errorMessage, Colors.red);
      await _logout();
    } catch (e) {
      _showSnackbar("Error", "Error inesperado al iniciar sesión.", Colors.red);
      await _logout();
    } finally {
      setState(() => _isLoading = false);
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
      setState(() => _isLoading = true);

      // 1. Verificar conexión a internet primero
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw SocketException('No internet');
        }
      } on SocketException catch (_) {
        throw FirebaseAuthException(
          code: 'no-internet',
          message: 'Sin conexión a internet. Revisa tus datos móviles o WiFi',
        );
      }

      // 2. Intentar autenticación (con reintento)
      UserCredential? userCredential;
      int attempts = 0;
      const maxAttempts = 2;

      while (attempts < maxAttempts) {
        try {
          userCredential = await AuthService().signInWithGoogle().timeout(
                const Duration(seconds: 30),
                onTimeout: () =>
                    throw TimeoutException('Tiempo de espera agotado'),
              );
          break;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'network-error' && attempts < maxAttempts - 1) {
            await Future.delayed(const Duration(seconds: 1));
            attempts++;
            continue;
          }
          rethrow;
        }
      }

      if (userCredential == null) {
        throw FirebaseAuthException(
          code: 'auth-failed',
          message: 'No se pudo completar la autenticación',
        );
      }

      // 3. Guardar datos locales
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userCredential.user!.uid);
      await prefs.setString('loginMethod', 'google');

      // 4. Manejar usuario nuevo/existente
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      final String role = userDoc.exists
          ? userDoc['role'] ?? 'Usuario Normal'
          : 'Usuario Normal';
      await prefs.setString('userRole', role);

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'name': userCredential.user?.displayName,
          'photoUrl': userCredential.user?.photoURL,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. Redirigir según rol
      _redirectBasedOnRole(role);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      final String errorMessage = _getFriendlyErrorMessage(e.code);

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () => _loginWithGoogle(),
          child:
              const Text('Reintentar', style: TextStyle(color: Colors.white)),
        ),
      );
    } on TimeoutException catch (_) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error',
        'El servicio está tardando demasiado. Revisa tu conexión',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange[600],
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error completo: $e');
      Get.snackbar(
        'Error',
        'Ocurrió un problema inesperado. Intenta nuevamente',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getFriendlyErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'no-internet':
        return 'No hay conexión a internet. Revisa tus datos móviles o WiFi';
      case 'network-error':
        return 'Problema de red. Tu operador móvil podría estar bloqueando la conexión';
      case 'user-cancelled':
        return '';
      case 'account-exists-with-different-credential':
        return 'Esta cuenta ya está registrada con otro método';
      case 'invalid-credential':
        return 'Credenciales inválidas. Intenta nuevamente';
      default:
        return 'Error al iniciar sesión con Google';
    }
  }

  void _redirectBasedOnRole(String role) {
    switch (role) {
      case "Admin":
        Get.offAll(() => SalespointNewSalePage());
        break;
      case "Dueño de Negocio":
        Get.offAll(() => BusinessOwnerScreen());
        break;
      default:
        Get.offAll(() => StoreScreen());
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

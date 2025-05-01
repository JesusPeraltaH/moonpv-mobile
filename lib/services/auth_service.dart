import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Future<UserCredential> signInWithGoogle() async {
  //   // Trigger the authentication flow
  //   final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

  //   // Obtain the auth details from the request
  //   final GoogleSignInAuthentication? googleAuth =
  //       await googleUser?.authentication;

  //   // Create a new credential
  //   final credential = GoogleAuthProvider.credential(
  //     accessToken: googleAuth?.accessToken,
  //     idToken: googleAuth?.idToken,
  //   );

  //   // Once signed in, return the UserCredential
  //   return await FirebaseAuth.instance.signInWithCredential(credential);
  // }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // 1. Configuración específica por plataforma (revisar si es necesario)
      if (defaultTargetPlatform == TargetPlatform.android) {
        // await _firebaseAuth.setSettings( // Comentado para probar sin esta configuración
        //   appVerificationDisabledForTesting: false,
        //   forceRecaptchaFlow: true, // Forzar reCAPTCHA visible en físico
        // );
      }

      // 2. Configuración dinámica de Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: Platform.isIOS
            ? '904853707508-rsmbt368keakgllp8qsascmpocmgg0v9.apps.googleusercontent.com' // Reemplaza con tu ID de cliente de iOS
            : null,
        // serverClientId: Platform.isAndroid // Eliminar serverClientId para Android en el cliente
        //     ? 'TU_SERVER_CLIENT_ID_ANDROID' // Reemplaza con tu Server Client ID si lo necesitas en el backend
        //     : null,
        signInOption: SignInOption.standard,
      );

      // 3. Iniciar flujo con manejo de desconexión
      final GoogleSignInAccount? googleUser = await _executeWithNetworkCheck(
        () => googleSignIn.signIn().timeout(
              const Duration(seconds: 25),
            ),
      );

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'user-cancelled',
          message: 'Inicio de sesión cancelado por el usuario',
        );
      }

      // 4. Obtener tokens con validación
      final GoogleSignInAuthentication? googleAuth =
          await _executeWithNetworkCheck(
        () => googleUser.authentication.timeout(
          const Duration(seconds: 20),
        ),
      );

      if (googleAuth?.accessToken == null || googleAuth?.idToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-tokens',
          message: 'Error en los tokens de autenticación',
        );
      }

      // 5. Autenticar con Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth!.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _executeWithNetworkCheck(
        () => _firebaseAuth.signInWithCredential(credential).timeout(
              const Duration(seconds: 20),
            ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('Platform Error: ${e.code} - ${e.message}');
      throw FirebaseAuthException(
        code: e.code,
        message: _translatePlatformError(e),
      );
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      throw FirebaseAuthException(
        code: 'operation-failed',
        message: 'Error inesperado: ${e.toString()}',
      );
    }
  }

  // Helper para manejo de conexión
  Future<T> _executeWithNetworkCheck<T>(Future<T> Function() operation) async {
    try {
      if (!await _checkInternetConnection()) {
        throw FirebaseAuthException(
          code: 'network-unavailable',
          message: 'Sin conexión a internet',
        );
      }
      return await operation();
    } on SocketException catch (_) {
      throw FirebaseAuthException(
        code: 'network-error',
        message: 'Error de red. Revisa tu conexión',
      );
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _translatePlatformError(PlatformException e) {
    switch (e.code) {
      case 'sign_in_failed':
        return 'Error en el inicio de sesión. Intenta nuevamente';
      case 'sign_in_canceled':
        return 'Inicio de sesión cancelado';
      case 'network_error':
        return 'Error de red. Revisa tu conexión móvil o WiFi';
      case 'internal_error':
        return 'Error interno del servicio Google';
      default:
        return 'Error en la plataforma: ${e.message ?? 'Desconocido'}';
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error creating user: $e");
      // Puedes lanzar la excepción nuevamente para que el widget la maneje
      throw e;
    } catch (e) {
      print("Generic Error creating user: $e");
      throw e;
    }
  }

  Future<void> sigOut() async {
    return await _firebaseAuth.signOut();
  }
}

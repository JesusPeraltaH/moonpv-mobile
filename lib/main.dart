import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/screens/IntermidScreen.dart';
import 'package:moonpv/theme/zara_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print("Inicializando Firebase..."); // Debug
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print("Firebase inicializado correctamente"); // Debug
    
    runApp(const MyApp());
  } catch (e) {
    print("ERROR CRÍTICO: $e"); // Verás esto en la consola si hay fallos
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text("Error al iniciar: $e", style: TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MoonConcept Store',
      debugShowCheckedModeBanner: false,
      theme: ZaraTheme.lightTheme,
      darkTheme: ZaraTheme.darkTheme,
      home: IntermidScreen(), // Widget que maneja el splash
    );
  }
}

// class SplashWrapper extends StatefulWidget {
//   const SplashWrapper({Key? key}) : super(key: key);

//   @override
//   _SplashWrapperState createState() => _SplashWrapperState();
// }

// class _SplashWrapperState extends State<SplashWrapper> {
//   @override
//   void initState() {
//     super.initState();
//     _navigateToNext();
//   }

//   void _navigateToNext() async {
//     // Espera 2 segundos o hasta que Firebase esté listo
//     await Future.delayed(const Duration(seconds: 2));
    
//     Get.off(() => IntermidScreen()); // Navegación con GetX
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         color: Colors.white, // Mismo color que el splash nativo
//         child: Center(
//           child: Image.asset(
//             'assets/icon/app_icon.png', // Tu logo
//             width: 200,
//             height: 200,
//             errorBuilder: (context, error, stackTrace) => CircularProgressIndicator(),
//           ),
//         ),
//       ),
//     );
//   }
// }
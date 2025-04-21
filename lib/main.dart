import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:firebase_core/firebase_core.dart';
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

import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'firebase_options.dart'; // Asegúrate de importar esto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar las variables de entorno antes de Firebase
  await dotenv.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions
          .currentPlatform, // Usando las opciones configuradas
    );
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Moon PV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SalespointNewSalePage(),
    );
  }
}

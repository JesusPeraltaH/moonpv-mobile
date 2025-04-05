import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:moonpv/screens/splashScreen.dart';
import 'package:moonpv/theme/zara_theme.dart';
import 'firebase_options.dart'; // Asegúrate de importar esto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
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
      home: SplashScreen(),
    );
  }
}

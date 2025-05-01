// import 'package:firebase_app_check/firebase_app_check.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get/get_navigation/src/root/get_material_app.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:moonpv/screens/IntermidScreen.dart';
// import 'package:moonpv/theme/zara_theme.dart';
// import 'firebase_options.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     print("Inicializando Firebase..."); // Debug
//     await Firebase.initializeApp(
//         options: DefaultFirebaseOptions.currentPlatform);
//     print("Firebase inicializado correctamente"); // Debug

//     // Inicializa Firebase App Check
//     await FirebaseAppCheck.instance.activate(
//       androidProvider:
//           AndroidProvider.debug, // Para pruebas en Android Emulator
//       appleProvider: AppleProvider.debug, // Para pruebas en iOS Simulator
//       webProvider: ReCaptchaV3Provider(
//           '6LdSuiUrAAAAAHGzwZM9Hh6lyQ66vLHTqTtvj_4V'), // Si usas Firebase Hosting
//     );
//     print("Firebase App Check activado"); // Debug

//     runApp(const MyApp());
//   } catch (e) {
//     print("ERROR CRÍTICO: $e"); // Verás esto en la consola si hay fallos
//     runApp(
//       MaterialApp(
//         home: Scaffold(
//           body: Center(
//             child: Text("Error al iniciar: $e",
//                 style: TextStyle(color: Colors.red)),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       title: 'MoonConcept Store',
//       debugShowCheckedModeBanner: false,
//       theme: ZaraTheme.lightTheme,
//       darkTheme: ZaraTheme.darkTheme,
//       home: IntermidScreen(), // Widget que maneja el splash
//     );
//   }
// }

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:moonpv/inventory/inventory_page.dart';
import 'package:moonpv/point_sale/point_sale_newpage.dart';
import 'package:moonpv/screens/IntermidScreen.dart';
import 'package:moonpv/theme/zara_theme.dart';
import 'firebase_options.dart';

class RouteObserverImpl extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    print(
        'PUSHED: ${route.settings.name}, previous: ${previousRoute?.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    print(
        'POPPED: ${route.settings.name}, current: ${previousRoute?.settings.name}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    print(
        'REMOVED: ${route.settings.name}, previous: ${previousRoute?.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    print(
        'REPLACED: ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didStartUserGesture(route, previousRoute);
    print('USER GESTURE STARTED on: ${route.settings.name}');
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();
    print('USER GESTURE STOPPED');
  }
}

final routeObserver = RouteObserverImpl();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print("Inicializando Firebase..."); // Debug
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print("Firebase inicializado correctamente"); // Debug

    // Inicializa Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          AndroidProvider.debug, // Para pruebas en Android Emulator
      appleProvider: AppleProvider.debug, // Para pruebas en iOS Simulator
      webProvider: ReCaptchaV3Provider(
          '6LdSuiUrAAAAAHGzwZM9Hh6lyQ66vLHTqTtvj_4V'), // Si usas Firebase Hosting
    );
    print("Firebase App Check activado"); // Debug

    runApp(const MyApp());
  } catch (e) {
    print("ERROR CRÍTICO: $e"); // Verás esto en la consola si hay fallos
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text("Error al iniciar: $e",
                style: TextStyle(color: Colors.red)),
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
      navigatorObservers: [routeObserver], // Aquí implementamos el observer
      getPages: [
        GetPage(
            name: '/inventory',
            page: () =>
                InventoryPage()), // Asegúrate de que InventoryPage tenga una ruta nombrada
        GetPage(
            name: '/sales_new',
            page: () =>
                SalespointNewSalePage()), // Asegúrate de que SalespointNewSalePage tenga una ruta nombrada
        // Define otras rutas de tu aplicación aquí
      ],
    );
  }
}

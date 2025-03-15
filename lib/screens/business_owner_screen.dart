import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:moonpv/screens/login_screen.dart'; // For charts

class BusinessOwnerScreen extends StatelessWidget {
  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Get.offAll(
          () => LoginScreen()); // Navega a la pantalla de inicio de sesión
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Panel de Jefe de Negocio"),
        actions: [
          // 🔥 Menú desplegable para carrito y logout
          PopupMenuButton<String>(
            icon: const Icon(Icons.shopping_cart),
            onSelected: (value) {
              if (value == 'cart') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Carrito de compras")),
                );
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'cart',
                child: Text('Ver Carrito'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeMessage(),
            SizedBox(height: 20),
            _buildLineChart(),
            SizedBox(height: 20),
            _buildBusinessInfoCard(),
          ],
        ),
      ),
    );
  }

  // Widget for the welcome message
  Widget _buildWelcomeMessage() {
    return Text(
      "Bienvenido, Business Owner",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Widget for the line chart
  Widget _buildLineChart() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: 6,
            lineBarsData: [
              LineChartBarData(
                spots: [
                  FlSpot(0, 3),
                  FlSpot(1, 1),
                  FlSpot(2, 4),
                  FlSpot(3, 2),
                  FlSpot(4, 5),
                  FlSpot(5, 1),
                  FlSpot(6, 4),
                ],
                isCurved: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for the business information card
  Widget _buildBusinessInfoCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Información del Negocio",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Aquí puedes mostrar información relevante sobre tu negocio.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 20),
            // Space to add more content
            Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "Contenido adicional aquí",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

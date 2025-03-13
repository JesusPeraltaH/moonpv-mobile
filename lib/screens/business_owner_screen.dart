import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // For charts

class BusinessOwnerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Panel de Jefe de Negocio"),
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

// screens/payment_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:moonpv/model/payment_model.dart';

class PaymentManagementScreen extends StatefulWidget {
  @override
  _PaymentManagementScreenState createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DateTime _currentMonth;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _checkMonthReset();
    _loadBusinesses();
  }

  Future<void> _checkMonthReset() async {
    final lastReset =
        await _firestore.collection('config').doc('payments').get();
    final lastResetDate = lastReset.exists
        ? (lastReset.data()?['lastReset'] as Timestamp?)?.toDate()
        : null;

    if (lastResetDate == null || lastResetDate.month != _currentMonth.month) {
      await _resetAllPayments();
      await _firestore.collection('config').doc('payments').set({
        'lastReset': Timestamp.fromDate(_currentMonth),
      });
    }
  }

  Future<void> _resetAllPayments() async {
    final businesses = await _firestore.collection('negocios').get();
    final batch = _firestore.batch();

    for (var doc in businesses.docs) {
      batch.update(doc.reference, {'pagoActual': false});
    }

    await batch.commit();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    // Aquí puedes cargar datos adicionales si es necesario
    setState(() => _isLoading = false);
  }

  Future<void> _togglePaymentStatus(
      String businessId, bool currentStatus) async {
    try {
      await _firestore.collection('negocios').doc(businessId).update({
        'pagoActual': !currentStatus,
        'ultimoPago': currentStatus ? null : Timestamp.now(),
        'historialPagos': FieldValue.arrayUnion([Timestamp.now()]),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el pago: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Gestión de Pagos Mensuales - ${DateFormat('MMMM y').format(_currentMonth)}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBusinesses,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('negocios').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final businesses = snapshot.data!.docs
                    .map((doc) => BusinessPayment.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  itemCount: businesses.length,
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(business.businessName),
                        subtitle: Text(
                          business.lastPaymentDate.year > 2000
                              ? 'Último pago: ${DateFormat('dd/MM/yyyy').format(business.lastPaymentDate)}'
                              : 'Sin pagos registrados',
                        ),
                        trailing: Switch(
                          value: business.isPaid,
                          onChanged: (value) => _togglePaymentStatus(
                              business.id, business.isPaid),
                          activeColor: Colors.green,
                        ),
                        leading: business.isPaid
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Icon(Icons.warning, color: Colors.orange),
                        onTap: () => _showPaymentHistory(context, business),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showPaymentHistory(BuildContext context, BusinessPayment business) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Historial de pagos - ${business.businessName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (business.paymentHistory.isEmpty)
                  Text('No hay pagos registrados')
                else
                  ...business.paymentHistory
                      .map((date) => ListTile(
                            title: Text(DateFormat('MMMM y').format(date)),
                            trailing:
                                Text(DateFormat('dd/MM/yyyy').format(date)),
                          ))
                      .toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

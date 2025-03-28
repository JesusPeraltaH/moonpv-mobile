// models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessPayment {
  final String id;
  final String businessName;
  bool isPaid;
  final DateTime lastPaymentDate;
  final List<DateTime> paymentHistory;

  BusinessPayment({
    required this.id,
    required this.businessName,
    required this.isPaid,
    required this.lastPaymentDate,
    required this.paymentHistory,
  });

  factory BusinessPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessPayment(
      id: doc.id,
      businessName: data['nombre'] ?? 'Sin nombre',
      isPaid: data['pagoActual'] ?? false,
      lastPaymentDate:
          (data['ultimoPago'] as Timestamp?)?.toDate() ?? DateTime(2000),
      paymentHistory: (data['historialPagos'] as List<dynamic>?)
              ?.map((e) => (e as Timestamp).toDate())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': businessName,
      'pagoActual': isPaid,
      'ultimoPago': Timestamp.fromDate(lastPaymentDate),
      'historialPagos':
          paymentHistory.map((e) => Timestamp.fromDate(e)).toList(),
    };
  }
}

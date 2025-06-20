import 'package:flutter/material.dart';

class BusinessForm extends StatelessWidget {
  final TextEditingController companyNameController;
  final TextEditingController ownerNameController;
  final TextEditingController phoneController;
  final TextEditingController categoriaController;
  final bool isSaving;
  final Function() onSave;
  final Function() onCancel;

  const BusinessForm({
    Key? key,
    required this.companyNameController,
    required this.ownerNameController,
    required this.phoneController,
    required this.categoriaController,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información del Negocio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: companyNameController,
              decoration: InputDecoration(
                labelText: 'Nombre del Negocio',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: ownerNameController,
              decoration: InputDecoration(
                labelText: 'Nombre del Propietario',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 8),
            TextField(
              controller: categoriaController,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSaving ? null : onCancel,
                  child: Text('Cancelar'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

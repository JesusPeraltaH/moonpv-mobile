import 'package:flutter/material.dart';

// Variable global
double conversionRate = 18.50;

class TipoCambioBottomSheet extends StatefulWidget {
  @override
  _TipoCambioBottomSheetState createState() => _TipoCambioBottomSheetState();
}

class _TipoCambioBottomSheetState extends State<TipoCambioBottomSheet> {
  final TextEditingController _nuevoValorController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Al abrir la pantalla, automáticamente muestra el bottom sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarBottomSheet();
    });
  }

  void _mostrarBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite ajustar el tamaño del bottomsheet
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cambiar Tipo de Cambio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Valor actual: \$${conversionRate.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nuevoValorController,
                decoration: InputDecoration(
                  labelText: 'Nuevo tipo de cambio',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          await Future.delayed(Duration(milliseconds: 500));

                          final nuevoValor =
                              double.tryParse(_nuevoValorController.text);
                          if (nuevoValor != null) {
                            conversionRate = nuevoValor;
                          }

                          setState(() {
                            _isLoading = false;
                          });

                          Navigator.pop(context); // Cierra el bottom sheet
                        },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Cambiar', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(); // Pantalla vacía, el bottom sheet aparece enseguida
  }
}

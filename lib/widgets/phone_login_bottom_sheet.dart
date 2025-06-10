import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:moonpv/screens/store_screen.dart';
import 'package:moonpv/widgets/verification_code_screen.dart';

class PhoneLoginBottomSheet extends StatefulWidget {
  @override
  _PhoneLoginBottomSheetState createState() => _PhoneLoginBottomSheetState();
}

class _PhoneLoginBottomSheetState extends State<PhoneLoginBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _countryCodeController = TextEditingController(text: '+52');
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Iniciar sesión con teléfono',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _countryCodeController,
                      decoration: InputDecoration(
                        labelText: 'Lada',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa la lada';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Número de teléfono',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu número';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPhone,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.black : Colors.white),
                      )
                    : Text('CONTINUAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPhone() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final phoneNumber =
            '${_countryCodeController.text}${_phoneController.text}';
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-verification completed (Android only)
            await _auth.signInWithCredential(credential);
            Navigator.pop(context); // Close bottom sheet
            Get.off(() => StoreScreen());
          },
          verificationFailed: (FirebaseAuthException e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.message}')),
            );
            setState(() {
              _isLoading = false;
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            Navigator.pop(context); // Close bottom sheet
            Get.to(() => VerificationCodeScreen(
                  verificationId: verificationId,
                  phoneNumber: phoneNumber,
                ));
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            // Handle timeout
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _countryCodeController.dispose();
    super.dispose();
  }
}

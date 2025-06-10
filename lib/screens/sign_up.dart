import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../screens/store_screen.dart';

class CreateAccountBottomSheet extends StatefulWidget {
  @override
  _CreateAccountBottomSheetState createState() =>
      _CreateAccountBottomSheetState();
}

class _CreateAccountBottomSheetState extends State<CreateAccountBottomSheet>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  int _step = 1;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _privacyPolicyAccepted = false;
  AnimationController? _titleAnimationController;
  Animation<double>? _titleAnimation;
  double _titlePosition = 0.0;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _updateTitleAnimation(_step);
    _titleAnimationController!.forward();
  }

  @override
  void dispose() {
    _titleAnimationController?.dispose();
    super.dispose();
  }

  void _updateTitleAnimation(int newStep) {
    double targetPosition = 0.0;
    if (newStep == 1) {
      targetPosition = -0.090;
    } else if (newStep == 2) {
      targetPosition = 0.020;
    } else if (newStep == 3) {
      targetPosition = 0.20;
    }

    _titleAnimation = Tween<double>(begin: _titlePosition, end: targetPosition)
        .animate(CurvedAnimation(
      parent: _titleAnimationController!,
      curve: Curves.easeInOut,
    ));
    _titleAnimationController!.reset();
    _titleAnimationController!.forward();
    _titlePosition = targetPosition;
  }

  Future<void> _createUserAccount() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackbar("Error", "Las contraseñas no coinciden", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credenciales = await _authService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (credenciales?.user != null) {
        _showSnackbar("Bienvenido", "Cuenta creada con éxito", Colors.green);
        await Future.delayed(Duration(seconds: 2));
        Get.off(() => StoreScreen());
      } else {
        _showSnackbar("Error", "No se pudo crear la cuenta.", Colors.red);
      }
    } catch (e) {
      String errorMessage = "Error al crear la cuenta";
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = "Este correo electrónico ya está en uso.";
      } else if (e.toString().contains('weak-password')) {
        errorMessage = "La contraseña es demasiado débil.";
      }
      _showSnackbar("Error", errorMessage, Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: color,
      colorText: Colors.white,
      margin: EdgeInsets.all(10),
    );
  }

  bool _isValidEmail(String email) {
    // Una expresión regular básica para validar el formato del correo electrónico
    return RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$')
        .hasMatch(email);
  }

  void _nextStep() {
    if (_step == 1) {
      if (!_isValidEmail(_emailController.text.trim())) {
        _showSnackbar("Error",
            "Por favor, ingresa un correo electrónico válido.", Colors.red);
        return;
      }
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _updateTitleAnimation(_step);
      });
    } else {
      if (!_privacyPolicyAccepted) {
        _showSnackbar(
            "Error",
            "Debes aceptar las políticas de privacidad para continuar.",
            Colors.red);
        return;
      }
      _createUserAccount();
    }
  }

  void _previousStep() {
    if (_step > 1) {
      setState(() {
        _step--;
        _updateTitleAnimation(_step);
      });
    }
  }

  Widget _buildNavigationButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    if (_step == 1) {
      return IconButton(
        icon: Icon(Icons.close, color: iconColor),
        onPressed: () => Get.back(),
      );
    } else {
      return IconButton(
        icon: Icon(Icons.arrow_back, color: iconColor),
        onPressed: _previousStep,
      );
    }
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return SlideInLeft(
          key: ValueKey(1),
          child: _buildEmailStep(),
        );
      case 2:
        return SlideInLeft(
          key: ValueKey(2),
          child: _buildPasswordStep(),
        );
      case 3:
        return SlideInLeft(
          key: ValueKey(3),
          child: _buildConfirmPasswordStep(),
        );
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildEmailStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingresa tu correo electrónico',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                spreadRadius: 1.0,
                offset: Offset(0, 0),
              ),
            ],
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: iconColor),
            decoration: InputDecoration(
              hintText: 'ejemplo@correo.com',
              hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
              prefixIcon: Icon(Icons.email, color: iconColor),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crea una contraseña segura',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                spreadRadius: 1.0,
                offset: Offset(0, 0),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: iconColor),
            decoration: InputDecoration(
              hintText: 'Mínimo 6 caracteres',
              hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
              prefixIcon: Icon(Icons.lock, color: iconColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: iconColor,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirma tu contraseña',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                spreadRadius: 1.0,
                offset: Offset(0, 0),
              ),
            ],
          ),
          child: TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: iconColor),
            decoration: InputDecoration(
              hintText: 'Reingresa tu contraseña',
              hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
              prefixIcon: Icon(Icons.lock, color: iconColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: iconColor,
                ),
                onPressed: () {
                  setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Checkbox(
              value: _privacyPolicyAccepted,
              onChanged: (bool? value) {
                setState(() {
                  _privacyPolicyAccepted = value ?? false;
                });
              },
              activeColor: isDark ? Colors.white : Colors.black,
              checkColor: isDark ? Colors.black : Colors.white,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _privacyPolicyAccepted = !_privacyPolicyAccepted;
                  });
                },
                child: Text(
                  'Acepto las políticas de privacidad y términos de uso',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavigationButton(),
                AnimatedBuilder(
                  animation: _titleAnimationController!,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          MediaQuery.of(context).size.width *
                              _titleAnimation!.value,
                          0.0),
                      child: child,
                    );
                  },
                  child: Text(
                    'Crear Cuenta',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
            SizedBox(height: 30),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final inFromRight = Tween<Offset>(
                  begin: Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation);
                final inFromLeft = Tween<Offset>(
                  begin: Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation);

                final offsetAnimation = _step == 1 ? inFromRight : inFromLeft;

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _buildStepContent(),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000000),
                  foregroundColor: isDark ? Colors.white : Colors.white,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  elevation: isDark ? 4 : 2,
                  shadowColor: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.2),
                ),
                onPressed: _isLoading ? null : _nextStep,
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white))
                    : Text(_step < 3 ? 'Siguiente' : 'Crear Cuenta',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            SizedBox(height: 15),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  '¿Ya tienes una cuenta? Iniciar sesión',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

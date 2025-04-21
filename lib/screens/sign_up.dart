import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../screens/store_screen.dart';

class CreateAccountBottomSheet extends StatefulWidget {
  @override
  _CreateAccountBottomSheetState createState() => _CreateAccountBottomSheetState();
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

    _titleAnimation = Tween<double>(begin: _titlePosition, end: targetPosition).animate(CurvedAnimation(
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
    return RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(email);
  }

 void _nextStep() {
    if (_step == 1) {
      if (!_isValidEmail(_emailController.text.trim())) {
        _showSnackbar("Error", "Por favor, ingresa un correo electrónico válido.", Colors.red);
        return;
      }
    }
    if (_step < 3) {
      setState(() {
        _step++;
        _updateTitleAnimation(_step);
      });
    } else {
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
    if (_step == 1) {
      return IconButton(
        icon: Icon(Icons.close),
        onPressed: () => Get.back(),
      );
    } else {
      return IconButton(
        icon: Icon(Icons.arrow_back),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingresa tu correo electrónico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'ejemplo@correo.com',
           
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Crea una contraseña segura', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Mínimo 6 caracteres',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirma tu contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: 'Reingresa tu contraseña',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
              _buildNavigationButton(), // Utiliza la función para el botón de navegación
              AnimatedBuilder(
                animation: _titleAnimationController!,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(MediaQuery.of(context).size.width * _titleAnimation!.value, 0.0),
                    child: child,
                  );
                },
                child: Text(
                  'Crear Cuenta',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 48), // Espacio para alinear el título
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
                padding: EdgeInsets.symmetric(vertical: 15),
               
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading ? null : _nextStep,
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white))
                  : Text(_step < 3 ? 'Siguiente' : 'Crear Cuenta', style: TextStyle(fontSize: 16)),
            ),
          ),
          SizedBox(height: 15),
          Center(
            child: TextButton(
              onPressed: () => Get.back(),
              child: Text('¿Ya tienes una cuenta? Iniciar sesión', style: TextStyle(color: Colors.grey[700])),
            ),
          ),
        ],
      ),
    );
  }
}
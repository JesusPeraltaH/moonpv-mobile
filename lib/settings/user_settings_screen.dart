import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:moonpv/inventory/main_drawer.dart';
import 'package:moonpv/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettingsScreen extends StatefulWidget {
  @override
  _UserSettingsScreenState createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _fotoUrl;
  String _nombre = 'Usuario';
  String _email = '';
  String _rol = 'Cliente';
  List<Map<String, dynamic>> _cartItems = [];
  bool _showCartButton = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No hay usuario autenticado');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _fotoUrl = userData['fotoUrl'];
            _nombre = userData['nombre'] ?? userData['name'] ?? 'Usuario';
            _email = userData['email'] ?? user.email ?? '';
            _rol = userData['role'] == 'Usuario'
                ? 'Cliente'
                : (userData['role'] ?? 'Cliente');
            _isLoading = false;
          });
        }
      } else {
        print('No se encontró el documento del usuario');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error al cargar datos del usuario: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar sesión'),
        content: Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('isLoggedIn');
                await prefs.remove('userId');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cerrar sesión: $e')),
                );
              }
            },
            child: Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      _cartItems.add(product);
      _showCartButton = true;
    });
  }

  void _showOrderSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'Resumen de la Orden',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return ListTile(
                      leading: item['imageUrl'] != null
                          ? Image.network(
                              item['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : Icon(Icons.image, size: 50),
                      title: Text(item['name'] ?? 'Producto'),
                      subtitle: Text(
                          '\$${item['price']?.toStringAsFixed(2) ?? '0.00'}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _cartItems.removeAt(index);
                            if (_cartItems.isEmpty) {
                              _showCartButton = false;
                            }
                          });
                          Navigator.pop(context);
                          _showOrderSummary();
                        },
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_calculateTotal().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implementar proceso de pago
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    'Proceder al Pago',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateTotal() {
    return _cartItems.fold(0.0, (sum, item) {
      return sum + (item['price'] ?? 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : Colors.black;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mi Cuenta'),
        ),
        drawer: MainDrawer(
          logoutCallback: (context) {
            print('Cerrando sesión desde UserSettingsScreen');
          },
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Cuenta'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.grey.shade200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/moon_blanco.png'
                          : 'assets/images/moon_negro.png',
                      height: 50,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MoonConcept',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('Pedidos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navegar a pedidos
              },
            ),
            ListTile(
              leading: Icon(Icons.favorite),
              title: Text('Favoritos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navegar a favoritos
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configuración'),
              onTap: () {
                Get.to(UserSettingsScreen());
                // TODO: Navegar a favoritos
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Cerrar sesión'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      floatingActionButton: _showCartButton
          ? FloatingActionButton.extended(
              onPressed: _showOrderSummary,
              backgroundColor: Colors.blue,
              icon: Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                '${_cartItems.length} ${_cartItems.length == 1 ? 'item' : 'items'}',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: ListView(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _fotoUrl != null ? NetworkImage(_fotoUrl!) : null,
                  child: _fotoUrl == null
                      ? Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _nombre,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _rol == 'Usuario Normal' ? 'Cliente' : _rol,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.location_on, color: iconColor),
                    title: Text('Mis Direcciones'),
                    onTap: () {
                      // TODO: Implementar gestión de direcciones
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.privacy_tip, color: iconColor),
                    title: Text('Privacidad y Seguridad'),
                    onTap: () {
                      // TODO: Implementar configuración de privacidad
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.help_outline, color: iconColor),
                    title: Text('Preguntas Frecuentes'),
                    onTap: () {
                      // TODO: Implementar FAQ
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.notifications, color: iconColor),
                    title: Text('Notificaciones'),
                    onTap: () {
                      // TODO: Implementar configuración de notificaciones
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.payment, color: iconColor),
                    title: Text('Métodos de Pago'),
                    onTap: () {
                      // TODO: Implementar gestión de métodos de pago
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history, color: iconColor),
                    title: Text('Historial de Compras'),
                    onTap: () {
                      // TODO: Implementar historial de compras
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

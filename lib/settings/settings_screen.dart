import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moonpv/inventory/main_drawer.dart';
import 'package:moonpv/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _fotoUrl;
  String _nombre = 'Usuario';
  String _email = '';
  String _rol = 'Usuario';

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
            _rol = userData['role'] ?? 'Usuario';
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Configuración'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración'),
      ),
      drawer: MainDrawer(
        logoutCallback: (context) {
          print('Cerrando sesión desde InventoryPage');
        },
      ),
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
                        _rol,
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
                    leading: Icon(Icons.print, color: iconColor),
                    title: Text('Conectar Impresora'),
                    onTap: () {
                      // TODO: Implementar conexión de impresora
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history, color: iconColor),
                    title: Text('Bitácora de Movimientos'),
                    onTap: () {
                      // TODO: Implementar bitácora
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
                    leading: Icon(Icons.security, color: iconColor),
                    title: Text('Seguridad'),
                    onTap: () {
                      // TODO: Implementar configuración de seguridad
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.backup, color: iconColor),
                    title: Text('Respaldo de Datos'),
                    onTap: () {
                      // TODO: Implementar respaldo de datos
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.color_lens, color: iconColor),
                    title: Text('Apariencia'),
                    onTap: () {
                      // TODO: Implementar personalización de tema
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.help, color: iconColor),
                    title: Text('Ayuda y Soporte'),
                    onTap: () {
                      // TODO: Implementar sección de ayuda
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

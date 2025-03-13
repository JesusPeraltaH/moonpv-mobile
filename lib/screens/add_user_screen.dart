import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para Firebase Authentication

class CreateUserScreen extends StatefulWidget {
  @override
  _CreateUserScreenState createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  // Controladores para los campos de texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variables para almacenar los valores seleccionados
  String? _selectedBusiness;
  String? _selectedRole;

  // Lista de roles
  final List<String> _roles = ["Admin", "Dueño de Negocio", "Usuario Normal"];

  // Lista de negocios (se llenará desde Firestore)
  List<String> _businesses = [];

  // Referencia a Firestore y Firebase Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadBusinesses(); // Cargar negocios al iniciar la pantalla
  }

  // Función para cargar los negocios desde Firestore
  Future<void> _loadBusinesses() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('negocios').get();
      setState(() {
        _businesses = querySnapshot.docs
            .map((doc) => doc['nombreEmpresa'] as String)
            .toList();
      });
    } catch (e) {
      print("Error cargando negocios: $e");
    }
  }

  // Función para mostrar el Bottom Sheet con el formulario
  void _showAddUserBottomSheet() {
    bool _obscurePassword =
        true; // Variable local para controlar la visibilidad de la contraseña

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el Bottom Sheet sea más grande
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context)
                    .viewInsets
                    .bottom, // Ajusta el padding para el teclado
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Agregar Usuario",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Dropdown para seleccionar el rol
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      items: _roles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value;
                          if (value == "Admin") {
                            _selectedBusiness =
                                null; // Limpiar negocio si el rol es Admin
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Rol",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Dropdown para seleccionar el negocio (solo si el rol no es Admin)
                    if (_selectedRole != "Admin")
                      DropdownButtonFormField<String>(
                        value: _selectedBusiness,
                        items: _businesses.map((business) {
                          return DropdownMenuItem(
                            value: business,
                            child: Text(business),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBusiness = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: "Negocio",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_selectedRole != "Admin") SizedBox(height: 20),

                    // Campo para el nombre
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Nombre",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Campo para el correo
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Correo",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 20),

                    // Campo para la contraseña con "ojito"
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword; // Alternar entre mostrar/ocultar
                            });
                          },
                        ),
                      ),
                      obscureText:
                          _obscurePassword, // Controla si la contraseña está oculta
                    ),
                    SizedBox(height: 20),

                    // Botón para guardar el usuario
                    ElevatedButton(
                      onPressed: _saveUser,
                      child: Text("Guardar Usuario"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Función para guardar el usuario
  Future<void> _saveUser() async {
    if (_selectedRole == null ||
        (_selectedRole != "Admin" && _selectedBusiness == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Por favor, completa todos los campos")),
      );
      return;
    }

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Por favor, completa todos los campos")),
      );
      return;
    }

    try {
      // Crear un usuario en Firebase Authentication
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardar el usuario en Firestore
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        "name": name,
        "email": email,
        "business": _selectedBusiness,
        "role": _selectedRole,
      });

      // Limpia los campos después de guardar
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _selectedBusiness = null;
        _selectedRole = null;
      });

      // Cierra el Bottom Sheet
      Navigator.pop(context);

      // Muestra un mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Usuario creado exitosamente")),
      );
    } catch (e) {
      // Maneja errores
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al crear el usuario: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Crear Usuario"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Volver atrás
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No hay usuarios registrados"));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(
                  user["business"] ??
                      "Admin", // Muestra "Admin" si no hay negocio
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(user["name"]),
                trailing: Text(
                  user["role"],
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Botón flotante para abrir el Bottom Sheet
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserBottomSheet,
        child: Icon(Icons.add),
      ),
    );
  }
}

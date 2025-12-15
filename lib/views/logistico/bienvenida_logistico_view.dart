// lib/views/logistico/bienvenida_logistico_view.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class BienvenidaLogisticoView extends StatefulWidget {
  const BienvenidaLogisticoView({Key? key}) : super(key: key);

  @override
  _BienvenidaLogisticoViewState createState() => _BienvenidaLogisticoViewState();
}

class _BienvenidaLogisticoViewState extends State<BienvenidaLogisticoView> {
  User? _currentUser;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido Logístico'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono de bienvenida
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2,
                size: 60,
                color: Colors.purple.shade700,
              ),
            ),

            const SizedBox(height: 30),

            // Título
            const Text(
              '¡Bienvenido Logístico!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // Subtítulo
            const Text(
              'Sistema de Gestión Logística de Empadronamiento',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Información del usuario
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.purple),
                      title: Text('Usuario'),
                      subtitle: Text(_currentUser?.username ?? 'Cargando...'),
                    ),
                    ListTile(
                      leading: Icon(Icons.email, color: Colors.purple),
                      title: Text('Email'),
                      subtitle: Text(_currentUser?.email ?? 'Cargando...'),
                    ),
                    ListTile(
                      leading: Icon(Icons.assignment_ind, color: Colors.purple),
                      title: Text('Rol'),
                      subtitle: Text(_currentUser?.groups.isNotEmpty == true
                          ? _currentUser!.groups.join(', ')
                          : 'Logístico'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Instrucciones
            Card(
              elevation: 2,
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrucciones:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionItem('1. Utilice el menú lateral para navegar'),
                    _buildInstructionItem('2. Seleccione "Llegada de Ruta" para registrar su llegada'),
                    _buildInstructionItem('3. Complete todos los campos requeridos'),
                    _buildInstructionItem('4. Asegúrese de tener GPS activado'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Botón de acción principal
            ElevatedButton.icon(
              onPressed: () {
                // Navegar a la vista de llegada de ruta
                Navigator.pop(context); // Cerrar drawer si está abierto
              },
              icon: Icon(Icons.flag, size: 24),
              label: const Text('Ir a Llegada de Ruta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
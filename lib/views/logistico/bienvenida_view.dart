// Crea este nuevo archivo: lib/views/bienvenida_view.dart

import 'package:flutter/material.dart';

class BienvenidaView extends StatelessWidget {
  final String username;
  final String userRole;

  const BienvenidaView({
    Key? key,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 100,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 24),
            Text(
              '¡Bienvenido, $username!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Has iniciado sesión como:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                userRole,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            const SizedBox(height: 32),
            const Text(
              'Utiliza el menú lateral para acceder a las opciones disponibles.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

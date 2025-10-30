import 'package:flutter/material.dart';

class OperadorView extends StatelessWidget {
  const OperadorView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Operador'),
        backgroundColor: Colors.blue,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vista Operador',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esta es la vista específica para el perfil de Operador.'),
                    SizedBox(height: 8),
                    Text('Aquí puedes agregar las funcionalidades específicas del operador.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
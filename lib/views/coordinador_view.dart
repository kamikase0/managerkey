import 'package:flutter/material.dart';

class CoordinadorView extends StatelessWidget {
  const CoordinadorView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Coordinador'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vista Coordinador',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Esta es la vista específica para el perfil de Coordinador.'),
                    SizedBox(height: 8),
                    Text('Aquí puedes agregar las funcionalidades específicas del coordinador.'),
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
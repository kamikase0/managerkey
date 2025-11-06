import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class HistorialSalidasScreen extends StatelessWidget {
  final _firestoreService = FirestoreService();

  HistorialSalidasScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Salidas'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.obtenerSalidasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hay salidas registradas'),
            );
          }

          final salidas = snapshot.data!;

          return ListView.builder(
            itemCount: salidas.length,
            itemBuilder: (context, index) {
              final salida = salidas[index];
              final fecha = (salida['fechaHora'] as dynamic).toDate();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(Icons.location_on,
                      color: Colors.red.shade600),
                  title: Text(
                    'Lat: ${salida['latitud'].toStringAsFixed(4)}, '
                        'Long: ${salida['longitud'].toStringAsFixed(4)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Observaciones: ${salida['observaciones']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${fecha.toString()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _firestoreService.eliminarSalida(salida['id']);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
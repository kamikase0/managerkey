// lib/widgets/simple_sync_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reporte_sync_manager.dart';

class SimpleSyncIndicator extends StatelessWidget {
  final VoidCallback? onSync;

  const SimpleSyncIndicator({Key? key, this.onSync}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final syncManager = ReporteSyncManager();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getSyncInfo(syncManager),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        if (!snapshot.hasData) {
          return _buildOfflineIndicator(context, onSync);
        }

        final data = snapshot.data!;
        final tieneConexion = data['tieneConexion'] as bool;
        final pendientes = data['pendientes'] as int;
        final isSyncing = data['isSyncing'] as bool;

        if (isSyncing) {
          return _buildSyncingIndicator();
        }

        if (!tieneConexion) {
          return _buildOfflineIndicator(context, onSync);
        }

        if (pendientes > 0) {
          return _buildPendingIndicator(context, pendientes, onSync);
        }

        return _buildSyncedIndicator();
      },
    );
  }

  Future<Map<String, dynamic>> _getSyncInfo(ReporteSyncManager syncManager) async {
    try {
      final tieneConexion = await syncManager.verificarConexion();
      final stats = await syncManager.obtenerEstadisticas();

      return {
        'tieneConexion': tieneConexion,
        'pendientes': stats['pendientes'] ?? 0,
        'isSyncing': false,
      };
    } catch (e) {
      return {
        'tieneConexion': false,
        'pendientes': 0,
        'isSyncing': false,
      };
    }
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSyncingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Sincronizando...',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator(BuildContext context, VoidCallback? onSync) {
    return GestureDetector(
      onTap: onSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              'Offline',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingIndicator(
      BuildContext context,
      int pendientes,
      VoidCallback? onSync,
      ) {
    return GestureDetector(
      onTap: onSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              '$pendientes',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(
            'Sincronizado',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
// lib/widgets/sync_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_models.dart';
import '../services/reporte_sync_service.dart';
//import '../models/sync_state.dart'; // ✅ Importar SyncState




class SyncIndicator extends StatelessWidget {
  final VoidCallback? onSync;

  const SyncIndicator({Key? key, this.onSync}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final syncService = Provider.of<ReporteSyncService>(context, listen: false);

    return FutureBuilder<SyncState>(
      future: syncService.getSyncState(), // ✅ Ahora devuelve Future<SyncState>
      builder: (context, snapshot) {
        // Estado de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        // Si hay error
        if (snapshot.hasError) {
          return _buildErrorIndicator(snapshot.error.toString());
        }

        // Si no hay datos
        if (!snapshot.hasData) {
          return _buildOfflineIndicator(context, onSync);
        }

        final state = snapshot.data!;

        // Verificar cada estado
        if (state.isSyncing) {
          return _buildSyncingIndicator();
        }

        if (state.offlineMode) {
          return _buildOfflineIndicator(context, onSync);
        }

        if (state.hasPendingSync && state.pendingReports > 0) {
          return _buildPendingIndicator(context, state, onSync);
        }

        return _buildSyncedIndicator();
      },
    );
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
      SyncState state,
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
              '${state.pendingReports}',
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

  Widget _buildErrorIndicator(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Text(
            'Error',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
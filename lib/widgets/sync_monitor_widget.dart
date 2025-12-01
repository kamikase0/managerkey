// sync_monitor_widget.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manager_key/services/database_service.dart';

class SyncMonitorWidget extends StatefulWidget {
  final VoidCallback? onSyncPressed;

  const SyncMonitorWidget({Key? key, this.onSyncPressed}) : super(key: key);

  @override
  _SyncMonitorWidgetState createState() => _SyncMonitorWidgetState();
}

class _SyncMonitorWidgetState extends State<SyncMonitorWidget> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic> _stats = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Actualizar cada 30 segundos
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _loadStats());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _dbService.obtenerEstadisticasDespliegueOffline();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _stats['pendientes'] ?? 0;
    final total = _stats['total'] ?? 0;
    final porcentaje = _stats['porcentaje'] ?? 0;
    final fallidos = _stats['fallidos'] ?? 0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pendientes > 0 ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pendientes > 0 ? Colors.orange : Colors.green,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📊 Sincronización Offline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: pendientes > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
              if (pendientes > 0 && widget.onSyncPressed != null)
                IconButton(
                  icon: Icon(Icons.sync, size: 20),
                  onPressed: widget.onSyncPressed,
                  color: Colors.blue,
                  tooltip: 'Sincronizar ahora',
                ),
            ],
          ),

          SizedBox(height: 8),

          Row(
            children: [
              _buildStatItem(
                label: 'Total',
                value: total.toString(),
                color: Colors.blue,
              ),
              SizedBox(width: 16),
              _buildStatItem(
                label: 'Pendientes',
                value: pendientes.toString(),
                color: pendientes > 0 ? Colors.orange : Colors.green,
              ),
              SizedBox(width: 16),
              _buildStatItem(
                label: 'Fallidos',
                value: fallidos.toString(),
                color: fallidos > 0 ? Colors.red : Colors.grey,
              ),
            ],
          ),

          SizedBox(height: 8),

          if (pendientes > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progreso: $porcentaje%',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                LinearProgressIndicator(
                  value: porcentaje / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    porcentaje == 100 ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),

          if (pendientes == 0 && total > 0)
            Text(
              '✅ Todo sincronizado',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
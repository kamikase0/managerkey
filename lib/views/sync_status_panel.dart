import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/reporte_sync_service.dart';

class SyncStatusPanel extends StatefulWidget {
  final VoidCallback? onSyncPressed;
  final VoidCallback? onCleanPressed;

  const SyncStatusPanel({
    Key? key,
    this.onSyncPressed,
    this.onCleanPressed,
  }) : super(key: key);

  @override
  State<SyncStatusPanel> createState() => _SyncStatusPanelState();
}

class _SyncStatusPanelState extends State<SyncStatusPanel> {
  late ReporteSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = context.read<ReporteSyncService>();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Panel de estado de sincronización
        Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO DE SINCRONIZACIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),

                // Estado general
                StreamBuilder<SyncStatus>(
                  stream: _syncService.syncStatusStream,
                  initialData: SyncStatus.synced,
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? SyncStatus.synced;
                    return _buildStatusIndicator(status);
                  },
                ),

                const SizedBox(height: 16),

                // Contador de reportes pendientes
                StreamBuilder<int>(
                  stream: _syncService.pendingCountStream,
                  initialData: 0,
                  builder: (context, snapshot) {
                    final pendientes = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pendientes > 0
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pendientes > 0
                              ? Colors.orange.shade300
                              : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pendientes > 0
                                ? Icons.cloud_upload
                                : Icons.check_circle,
                            color: pendientes > 0
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pendientes > 0
                                      ? 'Reportes Pendientes'
                                      : 'Todo Sincronizado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: pendientes > 0
                                        ? Colors.orange.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pendientes > 0
                                      ? '$pendientes reporte(s) esperando sincronización'
                                      : 'Todos los reportes están sincronizados',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (pendientes > 0)
                            Text(
                              pendientes.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.orange.shade700,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Progreso de sincronización
                StreamBuilder<SyncProgress>(
                  stream: _syncService.syncProgressStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final progress = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progreso: ${progress.actual}/${progress.total}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${progress.porcentaje}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.porcentaje / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation(
                              Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Estadísticas
                FutureBuilder<SyncStats>(
                  future: _syncService.getSyncStats(),
                  initialData: SyncStats(
                    totalReportes: 0,
                    sincronizados: 0,
                    pendientes: 0,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final stats = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildStatRow(
                            '📊 Total de Reportes',
                            stats.totalReportes.toString(),
                            Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            '✅ Sincronizados',
                            stats.sincronizados.toString(),
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            '⏳ Pendientes',
                            stats.pendientes.toString(),
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            '📈 Porcentaje',
                            '${stats.porcentajeSincronizado.toStringAsFixed(1)}%',
                            Colors.purple,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onSyncPressed ?? _sincronizarManualmente,
                        icon: const Icon(Icons.cloud_sync),
                        label: const Text('SINCRONIZAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onCleanPressed ?? _limpiarSincronizados,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('LIMPIAR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(SyncStatus status) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String titulo;
    String descripcion;

    switch (status) {
      case SyncStatus.synced:
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        titulo = 'Sincronizado';
        descripcion = 'Todos los reportes están actualizados';
        break;
      case SyncStatus.syncing:
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        textColor = Colors.blue.shade700;
        icon = Icons.hourglass_top;
        titulo = 'Sincronizando...';
        descripcion = 'Por favor, espera mientras se sincronizan los reportes';
        break;
      case SyncStatus.pending:
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade700;
        icon = Icons.cloud_off;
        titulo = 'Sin Conexión';
        descripcion = 'Los reportes se sincronizarán cuando haya conexión';
        break;
      case SyncStatus.error:
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        icon = Icons.error;
        titulo = 'Error de Sincronización';
        descripcion = 'Hubo un problema, intenta de nuevo';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (status == SyncStatus.syncing)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(textColor),
              ),
            )
          else
            Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sincronizarManualmente() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iniciando sincronización...'),
        duration: Duration(seconds: 2),
      ),
    );
    await _syncService.sincronizarReportes();
  }

  Future<void> _limpiarSincronizados() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpiar Reportes Sincronizados'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar los reportes ya sincronizados?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _syncService.limpiarReportesSincronizados();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reportes sincronizados eliminados'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('LIMPIAR'),
            ),
          ],
        );
      },
    );
  }
}
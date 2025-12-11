// lib/models/sync_models.dart

enum SyncStatus {
  synced,
  syncing,
  pending,
  error,
}

class SyncProgress {
  final int actual;
  final int total;
  final int porcentaje;

  SyncProgress({
    required this.actual,
    required this.total,
    required this.porcentaje,
  });
}

class SyncStats {
  final int totalReportes;
  final int sincronizados;
  final int pendientes;
  final double porcentajeSincronizado;

  SyncStats({
    required this.totalReportes,
    required this.sincronizados,
    required this.pendientes,
  }) : porcentajeSincronizado = totalReportes > 0
      ? (sincronizados / totalReportes * 100)
      : 0.0;
}

// lib/models/sync_state.dart
class SyncState {
  final bool isSyncing;
  final bool offlineMode;
  final bool hasPendingSync;
  final int pendingReports;
  final int pendingDeployments;
  final DateTime? lastSync;

  SyncState({
    required this.isSyncing,
    required this.offlineMode,
    required this.hasPendingSync,
    required this.pendingReports,
    required this.pendingDeployments,
    this.lastSync,
  });

  // Método factory para crear estado inicial
  factory SyncState.initial() {
    return SyncState(
      isSyncing: false,
      offlineMode: false,
      hasPendingSync: false,
      pendingReports: 0,
      pendingDeployments: 0,
      lastSync: null,
    );
  }

  // Método factory para crear desde JSON
  factory SyncState.fromJson(Map<String, dynamic> json) {
    return SyncState(
      isSyncing: json['isSyncing'] ?? false,
      offlineMode: json['offlineMode'] ?? false,
      hasPendingSync: json['hasPendingSync'] ?? false,
      pendingReports: json['pendingReports'] ?? 0,
      pendingDeployments: json['pendingDeployments'] ?? 0,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'])
          : null,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'isSyncing': isSyncing,
      'offlineMode': offlineMode,
      'hasPendingSync': hasPendingSync,
      'pendingReports': pendingReports,
      'pendingDeployments': pendingDeployments,
      'lastSync': lastSync?.toIso8601String(),
    };
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int? syncCount;

  SyncResult({
    required this.success,
    required this.message,
    this.syncCount,
  });
}
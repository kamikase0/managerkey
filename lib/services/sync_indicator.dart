// Añade esta clase en un archivo separado o al principio de sync_indicator.dart

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

  // Método factory para crear desde JSON si es necesario
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
}
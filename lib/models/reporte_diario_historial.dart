// lib/models/reporte_diario_historial_model.dart

// Enum para manejar los estados de sincronización de forma clara
enum EstadoSincronizacion { sincronizado, pendiente, fallido }

class ReporteDiarioHistorial {
  final int? id; // Puede ser el ID del servidor o el ID local
  final String fechaReporte;
  final int registrosR;
  final int registrosC;
  final String? incidencias;
  final String? observaciones;
  final String nombreEstacion;
  final EstadoSincronizacion estadoSincronizacion;

  ReporteDiarioHistorial({
    required this.id,
    required this.fechaReporte,
    required this.registrosR,
    required this.registrosC,
    this.incidencias,
    this.observaciones,
    required this.nombreEstacion,
    required this.estadoSincronizacion,
  });

  // Factory constructor para crear una instancia desde el JSON de la API
  factory ReporteDiarioHistorial.fromJson(Map<String, dynamic> json) {
    return ReporteDiarioHistorial(
      id: json['id'],
      fechaReporte: json['fecha_reporte'] ?? 'Fecha no disponible',
      // Aseguramos que los valores sean enteros
      registrosR: (json['registro_r'] ?? 0).toInt(),
      registrosC: (json['registro_c'] ?? 0).toInt(),
      incidencias: json['incidencias'],
      observaciones: json['observaciones'],
      // Asumiendo que la API devuelve el nombre de la estación
      nombreEstacion: json['nombre_estacion'] ?? 'Estación Desconocida',
      // Si viene de la API, está sincronizado
      estadoSincronizacion: EstadoSincronizacion.sincronizado,
    );
  }

  // Factory constructor para crear una instancia desde el mapa de la BD SQLite local
  factory ReporteDiarioHistorial.fromDb(Map<String, dynamic> map) {
    return ReporteDiarioHistorial(
      id: map['id'],
      fechaReporte: map['fecha_reporte'] ?? 'Fecha no disponible',
      registrosR: (map['registro_r'] ?? 0).toInt(),
      registrosC: (map['registro_c'] ?? 0).toInt(),
      incidencias: map['incidencias'],
      observaciones: map['observaciones'],
      // Para registros locales, podrías guardar el nombre o usar un placeholder
      nombreEstacion: 'Reporte Local',
      // El estado depende de la lógica, pero si está en la tabla de no sincronizados, es pendiente
      estadoSincronizacion: EstadoSincronizacion.pendiente,
    );
  }
}

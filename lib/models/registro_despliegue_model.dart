class RegistroDespliegue {
  final int? id; // ID local de SQLite
  final String destino;
  final String latitud;
  final String longitud;
  final String? descripcionReporte;
  final String estado; // "DESPLIEGUE" o "LLEGADA"
  final bool sincronizar;
  final String observaciones;
  final String incidencias;
  final String fechaHora;
  final int operadorId;
  final bool sincronizado; // ¿Ya fue enviado al servidor?
  final DateTime? fechaSincronizacion;

  RegistroDespliegue({
    this.id,
    required this.destino,
    required this.latitud,
    required this.longitud,
    this.descripcionReporte,
    required this.estado,
    required this.sincronizar,
    required this.observaciones,
    required this.incidencias,
    required this.fechaHora,
    required this.operadorId,
    this.sincronizado = false,
    this.fechaSincronizacion,
  });

  /// Convertir a JSON para enviar al servidor
  Map<String, dynamic> toJson() {
    return {
      "destino": destino,
      "latitud": double.tryParse(latitud) ?? 0.0,
      "longitud": double.tryParse(longitud) ?? 0.0,
      "descripcion_reporte": descripcionReporte,
      "estado": estado,
      "sincronizar": sincronizar,
      "observaciones": observaciones,
      "incidencias": incidencias,
      "fecha_hora": fechaHora,
      "operador": operadorId,
    };
  }

  /// Convertir a Map para guardar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'destino': destino,
      'latitud': latitud,
      'longitud': longitud,
      'descripcion_reporte': descripcionReporte,
      'estado': estado,
      'sincronizar': sincronizar ? 1 : 0,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'fecha_hora': fechaHora,
      'operador_id': operadorId,
      'sincronizado': sincronizado ? 1 : 0,
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
    };
  }

  /// ✅  Convierte al formato del endpoint de despliegue
  Map<String, dynamic> toApiMap() {
    return {
      "destino": destino,
      "latitud": latitud, // El endpoint espera "latitud_despliegue"
      "longitud": longitud, // El endpoint espera "longitud_despliegue"
      "estado": estado,
      "sincronizar": sincronizar,
      "observaciones": observaciones,
      "fue_desplegado": true, // Para reportes diarios siempre es true
      "fecha_hora": fechaHora, // El endpoint espera "fecha_hora_salida"
      "llego_destino": false, // Para reportes diarios siempre es false
      "operador": operadorId,
      // Campos que no están en tu modelo pero el endpoint podría esperar:
      "incidencias": incidencias,
      "descripcion_reporte": descripcionReporte,
    };
  }

  /// Crear desde Map de SQLite
  factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'],
      destino: map['destino'],
      latitud: map['latitud'].toString(),
      longitud: map['longitud'].toString(),
      descripcionReporte: map['descripcion_reporte'],
      estado: map['estado'],
      sincronizar: map['sincronizar'] == 1,
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      fechaHora: map['fecha_hora'],
      operadorId: map['operador_id'],
      sincronizado: map['sincronizado'] == 1,
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'])
          : null,
    );
  }

  /// Crear desde JSON del servidor
  factory RegistroDespliegue.fromJson(Map<String, dynamic> json) {
    return RegistroDespliegue(
      destino: json['destino'],
      latitud: json['latitud'].toString(),
      longitud: json['longitud'].toString(),
      descripcionReporte: json['descripcion_reporte'],
      estado: json['estado'],
      sincronizar: json['sincronizar'] ?? false,
      observaciones: json['observaciones'],
      incidencias: json['incidencias'],
      fechaHora: json['fecha_hora'],
      operadorId: json['operador'],
      sincronizado: true,
    );
  }

  /// Crear un nuevo registro (para LLEGADA) basado en el actual
  RegistroDespliegue crearRegistroLlegada({
    required String latitudLlegada,
    required String longitudLlegada,
    required String fechaHoraLlegada,
    required String observacionesLlegada,
    bool sincronizar = true,
  }) {
    return RegistroDespliegue(
      destino: this.destino,
      latitud: latitudLlegada,
      longitud: longitudLlegada,
      descripcionReporte: this.descripcionReporte,
      estado: "LLEGADA",
      sincronizar: sincronizar,
      observaciones: observacionesLlegada,
      incidencias: this.incidencias,
      fechaHora: fechaHoraLlegada,
      operadorId: this.operadorId,
      sincronizado: false,
    );
  }
}
class RegistroDespliegue {
  final int? id;
  final String latitud;
  final String longitud;
  final String? descripcionReporte;
  final String estado;
  final bool sincronizar;
  final String? observaciones;
  final String? incidencias;
  final String fechaHora;
  final int operadorId;
  final bool sincronizado;
  final int? centroEmpadronamiento;
  final String? fechaSincronizacion;

  RegistroDespliegue({
    this.id,
    required this.latitud,
    required this.longitud,
    this.descripcionReporte,
    required this.estado,
    required this.sincronizar,
    this.observaciones,
    this.incidencias,
    required this.fechaHora,
    required this.operadorId,
    required this.sincronizado,
    this.centroEmpadronamiento,
    this.fechaSincronizacion,
  });

  // âœ… MAPEO PARA SQFLITE (CAMELCASE)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitud': latitud,
      'longitud': longitud,
      'descripcionReporte': descripcionReporte,
      'estado': estado,
      'sincronizar': sincronizar ? 1 : 0,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'fechaHora': fechaHora,
      'operadorId': operadorId,
      'sincronizado': sincronizado ? 1 : 0,
      'centroEmpadronamiento': centroEmpadronamiento,
      'fechaSincronizacion': fechaSincronizacion,
    };
  }

  factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'],
      latitud: map['latitud'] ?? '',
      longitud: map['longitud'] ?? '',
      descripcionReporte: map['descripcionReporte'],
      estado: map['estado'] ?? 'DESPLIEGUE',
      sincronizar: map['sincronizar'] == 1,
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      fechaHora: map['fechaHora'] ?? '',
      operadorId: map['operadorId'] ?? 0,
      sincronizado: map['sincronizado'] == 1,
      centroEmpadronamiento: map['centroEmpadronamiento'],
      fechaSincronizacion: map['fechaSincronizacion'],
    );
  }

  // âœ… MAPEO PARA API (SNAKE_CASE)
  Map<String, dynamic> toApiMap() {
    return {
      'latitud': latitud,
      'longitud': longitud,
      'descripcion_reporte': descripcionReporte,
      'estado': estado,
      'sincronizar': sincronizar,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'fecha_hora': fechaHora,
      'operador': operadorId,
      'centro_empadronamiento': centroEmpadronamiento,
    };
  }

  factory RegistroDespliegue.fromApiMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'],
      latitud: map['latitud']?.toString() ?? '0.0',
      longitud: map['longitud']?.toString() ?? '0.0',
      descripcionReporte: map['descripcion_reporte'],
      estado: map['estado'],
      sincronizar: map['sincronizar'] ?? true,
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      fechaHora: map['fecha_hora'],
      operadorId: map['operador'],
      sincronizado: true,
      centroEmpadronamiento: map['centro_empadronamiento'],
      fechaSincronizacion: map['fecha_sincronizacion'],
    );
  }
}
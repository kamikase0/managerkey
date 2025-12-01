// models/registro_despliegue_model.dart
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

  // Nuevos campos para offline
  final int? idServidor;
  final String? fechaCreacionLocal;
  final int intentos;
  final String? ultimoIntento;
  final int? operador_id;
  final int? centro_empadronamiento_id;

  RegistroDespliegue({
    this.id,
    required this.latitud,
    required this.longitud,
    this.descripcionReporte,
    required this.estado,
    required this.sincronizar,
    required this.observaciones,
    required this.incidencias,
    required this.fechaHora,
    required this.operadorId,
    required this.sincronizado,
    this.centroEmpadronamiento,
    this.fechaSincronizacion,
    // Nuevos campos
    this.idServidor,
    this.fechaCreacionLocal,
    this.intentos = 0,
    this.ultimoIntento,
    this.operador_id,
    this.centro_empadronamiento_id,
  });

  factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'] as int?,
      latitud: map['latitud'] as String,
      longitud: map['longitud'] as String,
      descripcionReporte: map['descripcionReporte'] as String?,
      estado: map['estado'] as String,
      sincronizar: (map['sincronizar'] as int?) == 1,
      observaciones: map['observaciones'] as String?,
      incidencias: map['incidencias'] as String?,
      fechaHora: map['fechaHora'] as String,
      operadorId: map['operadorId'] as int? ?? map['operador_id'] as int? ?? 0,
      sincronizado: (map['sincronizado'] as int?) == 1,
      centroEmpadronamiento: map['centroEmpadronamiento'] as int? ??
          map['centro_empadronamiento_id'] as int?,
      fechaSincronizacion: map['fechaSincronizacion'] as String?,
      // Nuevos campos
      idServidor: map['idServidor'] as int?,
      fechaCreacionLocal: map['fechaCreacionLocal'] as String?,
      intentos: map['intentos'] as int? ?? 0,
      ultimoIntento: map['ultimoIntento'] as String?,
      operador_id: map['operador_id'] as int?,
      centro_empadronamiento_id: map['centro_empadronamiento_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
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
      // Nuevos campos
      'idServidor': idServidor,
      'fechaCreacionLocal': fechaCreacionLocal,
      'intentos': intentos,
      'ultimoIntento': ultimoIntento,
      'operador_id': operador_id ?? operadorId,
      'centro_empadronamiento_id': centro_empadronamiento_id ?? centroEmpadronamiento,
    };
  }

  Map<String, dynamic> toApiMap() {
    return {
      'fecha_hora': fechaHora,
      'operador': operador_id ?? operadorId,
      'estado': estado,
      'latitud': double.tryParse(latitud) ?? 0,
      'longitud': double.tryParse(longitud) ?? 0,
      'observaciones': observaciones,
      'sincronizar': sincronizar,
      'descripcion_reporte': descripcionReporte,
      'incidencias': incidencias,
      'centro_empadronamiento': centro_empadronamiento_id ?? centroEmpadronamiento,
    };
  }

  /// -----------------------------------------------------------------
  /// ✅ CONSTRUCTOR DESDE LA API
  /// Lee desde snake_case de la API y construye el objeto.
  /// -----------------------------------------------------------------
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
      sincronizado: true, // Se asume sincronizado porque viene de la API
      centroEmpadronamiento: map['centro_empadronamiento'],
      fechaSincronizacion: map['fecha_sincronizacion'],
    );
  }

    Map<String, dynamic> toJsonForApi() {
    return {
      'centro_empadronamiento': centroEmpadronamiento,
      'latitud': double.tryParse(latitud) ?? 0.0,
      'longitud': double.tryParse(longitud) ?? 0.0,
      'descripcion_reporte': descripcionReporte,
      'estado': estado,
      'sincronizar': sincronizar,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'fecha_hora': fechaHora,
      'operador': operadorId,
    };
  }
}

// // lib/models/registro_despliegue_model.dart
//
// class RegistroDespliegue {
//   final int? id;
//   final String latitud;
//   final String longitud;
//   final String? descripcionReporte;
//   final String estado;
//   final bool sincronizar;
//   final String? observaciones;
//   final String? incidencias;
//   final String fechaHora;
//   final int operadorId;
//   final bool sincronizado;
//   final int? centroEmpadronamiento;
//   final String? fechaSincronizacion;
//
//   RegistroDespliegue({
//     this.id,
//     required this.latitud,
//     required this.longitud,
//     this.descripcionReporte,
//     required this.estado,
//     required this.sincronizar,
//     this.observaciones,
//     this.incidencias,
//     required this.fechaHora,
//     required this.operadorId,
//     required this.sincronizado,
//     this.centroEmpadronamiento,
//     this.fechaSincronizacion,
//   });
//
//     Map<String, dynamic> toJsonForApi() {
//     return {
//       'centro_empadronamiento': centroEmpadronamiento,
//       'latitud': double.tryParse(latitud) ?? 0.0,
//       'longitud': double.tryParse(longitud) ?? 0.0,
//       'descripcion_reporte': descripcionReporte,
//       'estado': estado,
//       'sincronizar': sincronizar,
//       'observaciones': observaciones,
//       'incidencias': incidencias,
//       'fecha_hora': fechaHora,
//       'operador': operadorId,
//     };
//   }
//
//   /// -----------------------------------------------------------------
//   /// ✅ MAPEO PARA LA BASE DE DATOS LOCAL (SQFLITE)
//   /// Usa snake_case para coincidir con la definición de la tabla.
//   /// -----------------------------------------------------------------
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'latitud': latitud,
//       'longitud': longitud,
//       // 'descripcionReporte' -> No existe en tu tabla, no lo incluimos
//       'estado': estado,
//       'sincronizar': sincronizar ? 1 : 0,
//       'observaciones': observaciones,
//       'incidencias': incidencias,
//       'fecha_hora': fechaHora,      // snake_case
//       'operador': operadorId,     // snake_case
//       'sincronizado': sincronizado ? 1 : 0,
//       'centro_empadronamiento': centroEmpadronamiento, // snake_case
//       'fecha_sincronizacion': fechaSincronizacion,      // snake_case
//     };
//   }
//
//   /// -----------------------------------------------------------------
//   /// ✅ CONSTRUCTOR DESDE LA BASE DE DATOS LOCAL (SQFLITE)
//   /// Lee desde snake_case y construye el objeto.
//   /// -----------------------------------------------------------------
//   factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
//     return RegistroDespliegue(
//       id: map['id'],
//       latitud: map['latitud'] ?? '',
//       longitud: map['longitud'] ?? '',
//       // descripcionReporte no se lee porque no existe en la tabla
//       estado: map['estado'] ?? 'DESPLIEGUE',
//       sincronizar: map['sincronizar'] == 1,
//       observaciones: map['observaciones'],
//       incidencias: map['incidencias'],
//       fechaHora: map['fecha_hora'] ?? '', // snake_case
//       operadorId: map['operador'] ?? 0,   // snake_case
//       sincronizado: map['sincronizado'] == 1,
//       centroEmpadronamiento: map['centro_empadronamiento'], // snake_case
//       fechaSincronizacion: map['fecha_sincronizacion'],      // snake_case
//     );
//   }
//
//   /// -----------------------------------------------------------------
//   /// ✅ MAPEO PARA LA API (SNAKE_CASE)
//   /// Coincide con lo que tu API espera.
//   /// -----------------------------------------------------------------
//   Map<String, dynamic> toApiMap() {
//     return {
//       'latitud': latitud,
//       'longitud': longitud,
//       'descripcion_reporte': descripcionReporte,
//       'estado': estado,
//       'sincronizar': sincronizar,
//       'observaciones': observaciones,
//       'incidencias': incidencias,
//       'fecha_hora': fechaHora,
//       'operador': operadorId,
//       'centro_empadronamiento': centroEmpadronamiento,
//     };
//   }
//
//   /// -----------------------------------------------------------------
//   /// ✅ CONSTRUCTOR DESDE LA API
//   /// Lee desde snake_case de la API y construye el objeto.
//   /// -----------------------------------------------------------------
//   factory RegistroDespliegue.fromApiMap(Map<String, dynamic> map) {
//     return RegistroDespliegue(
//       id: map['id'],
//       latitud: map['latitud']?.toString() ?? '0.0',
//       longitud: map['longitud']?.toString() ?? '0.0',
//       descripcionReporte: map['descripcion_reporte'],
//       estado: map['estado'],
//       sincronizar: map['sincronizar'] ?? true,
//       observaciones: map['observaciones'],
//       incidencias: map['incidencias'],
//       fechaHora: map['fecha_hora'],
//       operadorId: map['operador'],
//       sincronizado: true, // Se asume sincronizado porque viene de la API
//       centroEmpadronamiento: map['centro_empadronamiento'],
//       fechaSincronizacion: map['fecha_sincronizacion'],
//     );
//   }
//
//   /// -----------------------------------------------------------------
//   /// ✅ MÉTODO COPYWITH
//   /// Útil para crear una copia del objeto modificando algunos campos.
//   /// -----------------------------------------------------------------
//   RegistroDespliegue copyWith({
//     int? id,
//     String? latitud,
//     String? longitud,
//     String? descripcionReporte,
//     String? estado,
//     bool? sincronizar,
//     String? observaciones,
//     String? incidencias,
//     String? fechaHora,
//     int? operadorId,
//     bool? sincronizado,
//     int? centroEmpadronamiento,
//     String? fechaSincronizacion,
//   }) {
//     return RegistroDespliegue(
//       id: id ?? this.id,
//       latitud: latitud ?? this.latitud,
//       longitud: longitud ?? this.longitud,
//       descripcionReporte: descripcionReporte ?? this.descripcionReporte,
//       estado: estado ?? this.estado,
//       sincronizar: sincronizar ?? this.sincronizar,
//       observaciones: observaciones ?? this.observaciones,
//       incidencias: incidencias ?? this.incidencias,
//       fechaHora: fechaHora ?? this.fechaHora,
//       operadorId: operadorId ?? this.operadorId,
//       sincronizado: sincronizado ?? this.sincronizado,
//       centroEmpadronamiento: centroEmpadronamiento ?? this.centroEmpadronamiento,
//       fechaSincronizacion: fechaSincronizacion ?? this.fechaSincronizacion,
//     );
//   }
// }

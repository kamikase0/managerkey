// lib/models/registro_despliegue_model.dart (VERSIÓN CORREGIDA)
import 'dart:convert';

class RegistroDespliegue {
  final int? id;
  final String fechaHora;
  final int operadorId;
  final String estado;
  final String latitud;
  final String longitud;
  final String? observaciones;
  final bool sincronizar;
  final String? descripcionReporte;
  final String? incidencias;
  final int? centroEmpadronamientoId;
  final int sincronizado;
  final String? fechaSincronizacion;
  final int? idServidor;
  final String fechaCreacionLocal;
  final int intentos;
  final String? ultimoIntento;
  final String? createdAt;
  final String? updatedAt;

  RegistroDespliegue({
    this.id,
    required this.fechaHora,
    required this.operadorId,
    required this.estado,
    required this.latitud,
    required this.longitud,
    this.observaciones,
    required this.sincronizar,
    this.descripcionReporte,
    this.incidencias,
    this.centroEmpadronamientoId,
    required this.sincronizado,
    this.fechaSincronizacion,
    this.idServidor,
    required this.fechaCreacionLocal,
    required this.intentos,
    this.ultimoIntento,
    this.createdAt,
    this.updatedAt,
  });

  // Método para crear desde un Map (para BD local)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha_hora': fechaHora,
      'operador_id': operadorId,
      'estado': estado,
      'latitud': latitud,
      'longitud': longitud,
      'observaciones': observaciones,
      'sincronizar': sincronizar ? 1 : 0,
      'descripcion_reporte': descripcionReporte,
      'incidencias': incidencias,
      'centro_empadronamiento_id': centroEmpadronamientoId,
      'sincronizado': sincronizado,
      'fecha_sincronizacion': fechaSincronizacion,
      'id_servidor': idServidor,
      'fecha_creacion_local': fechaCreacionLocal,
      'intentos': intentos,
      'ultimo_intento': ultimoIntento,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Método para crear desde un Map de la BD local
  factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'] as int?,
      fechaHora: map['fecha_hora'] as String,
      operadorId: map['operador_id'] as int,
      estado: map['estado'] as String,
      latitud: map['latitud'] as String,
      longitud: map['longitud'] as String,
      observaciones: map['observaciones'] as String?,
      sincronizar: (map['sincronizar'] as int?) == 1,
      descripcionReporte: map['descripcion_reporte'] as String?,
      incidencias: map['incidencias'] as String?,
      centroEmpadronamientoId: map['centro_empadronamiento_id'] as int?,
      sincronizado: map['sincronizado'] as int,
      fechaSincronizacion: map['fecha_sincronizacion'] as String?,
      idServidor: map['id_servidor'] as int?,
      fechaCreacionLocal: map['fecha_creacion_local'] as String,
      intentos: map['intentos'] as int,
      ultimoIntento: map['ultimo_intento'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  /// ✅ MÉTODO CORREGIDO: Convertir a JSON para API (campos camelCase)
  /// Garantiza que NO hay campos NULL innecesarios
  Map<String, dynamic> toApiMap() {
    print('🔄 Creando mapa para API (ID Local: $id)...');

    final mapa = {
      'fecha_hora': fechaHora, // ✅ NUNCA NULL
      'operadorId': operadorId,
      'estado': estado,
      'latitud': latitud,
      'longitud': longitud,
      'observaciones': observaciones ?? '',
      'sincronizar': sincronizar ? 1 : 0,
      'incidencias': incidencias ?? 'Ubicación capturada',
      'centro_empadronamiento': centroEmpadronamientoId, // ✅ NUNCA NULL
    };

    // ✅ Campos opcionales - solo incluir si tienen valor
    if (descripcionReporte != null) {
      mapa['descripcion_reporte'] = descripcionReporte;
    }
    if (fechaSincronizacion != null) {
      mapa['fecha_sincronizacion'] = fechaSincronizacion;
    }
    if (idServidor != null) {
      mapa['id_servidor'] = idServidor;
    }
    if (createdAt != null) {
      mapa['createdAt'] = createdAt;
    }
    if (updatedAt != null) {
      mapa['updatedAt'] = updatedAt;
    }

    print('✅ Mapa para API creado:');
    mapa.forEach((key, value) {
      print('  - $key: $value (${value.runtimeType})');
    });

    return mapa;
  }

  /// Método para crear desde un Map de la API (campos camelCase)
  factory RegistroDespliegue.fromApiMap(Map<String, dynamic> map) {
    // Manejar el caso donde sincronizar puede venir como int o bool
    dynamic sincronizarValue = map['sincronizar'];
    bool sincronizarBool;

    if (sincronizarValue is bool) {
      sincronizarBool = sincronizarValue;
    } else if (sincronizarValue is int) {
      sincronizarBool = sincronizarValue == 1;
    } else {
      sincronizarBool = true;
    }

    return RegistroDespliegue(
      id: map['id'] as int?,
      fechaHora: map['fechaHora'] as String,
      operadorId: map['operadorId'] as int,
      estado: map['estado'] as String,
      latitud: map['latitud'] as String,
      longitud: map['longitud'] as String,
      observaciones: map['observaciones'] as String?,
      sincronizar: sincronizarBool,
      descripcionReporte: map['descripcionReporte'] as String?,
      incidencias: map['incidencias'] as String?,
      centroEmpadronamientoId: map['centroEmpadronamiento'] as int?,
      sincronizado: map['sincronizado'] as int? ?? 0,
      fechaSincronizacion: map['fechaSincronizacion'] as String?,
      idServidor: map['idServidor'] as int?,
      fechaCreacionLocal: map['fechaCreacionLocal'] as String? ?? DateTime.now().toIso8601String(),
      intentos: map['intentos'] as int? ?? 0,
      ultimoIntento: map['ultimoIntento'] as String?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  // Factory simplificado para crear nuevos registros
  factory RegistroDespliegue.createNew({
    required String fechaHora,
    required int operadorId,
    required String estado,
    required String latitud,
    required String longitud,
    String? observaciones,
    bool sincronizar = true,
    String? descripcionReporte,
    String? incidencias,
    int? centroEmpadronamiento,
  }) {
    final now = DateTime.now().toIso8601String();

    // ✅ Validaciones
    if (fechaHora.isEmpty) {
      throw ArgumentError('fechaHora no puede estar vacío');
    }
    if (centroEmpadronamiento == null || centroEmpadronamiento == 0) {
      throw ArgumentError('centroEmpadronamiento no puede ser null o 0');
    }

    return RegistroDespliegue(
      fechaHora: fechaHora,
      operadorId: operadorId,
      estado: estado,
      latitud: latitud,
      longitud: longitud,
      observaciones: observaciones,
      sincronizar: sincronizar,
      descripcionReporte: descripcionReporte,
      incidencias: incidencias ?? 'Ubicación capturada',
      centroEmpadronamientoId: centroEmpadronamiento,
      sincronizado: 0,
      fechaSincronizacion: null,
      idServidor: null,
      fechaCreacionLocal: now,
      intentos: 0,
      ultimoIntento: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Método para crear copia con modificaciones
  RegistroDespliegue copyWith({
    int? id,
    String? fechaHora,
    int? operadorId,
    String? estado,
    String? latitud,
    String? longitud,
    String? observaciones,
    bool? sincronizar,
    String? descripcionReporte,
    String? incidencias,
    int? centroEmpadronamiento,
    int? sincronizado,
    String? fechaSincronizacion,
    int? idServidor,
    String? fechaCreacionLocal,
    int? intentos,
    String? ultimoIntento,
    String? createdAt,
    String? updatedAt,
  }) {
    return RegistroDespliegue(
      id: id ?? this.id,
      fechaHora: fechaHora ?? this.fechaHora,
      operadorId: operadorId ?? this.operadorId,
      estado: estado ?? this.estado,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      observaciones: observaciones ?? this.observaciones,
      sincronizar: sincronizar ?? this.sincronizar,
      descripcionReporte: descripcionReporte ?? this.descripcionReporte,
      incidencias: incidencias ?? this.incidencias,
      centroEmpadronamientoId: centroEmpadronamiento ?? this.centroEmpadronamientoId,
      sincronizado: sincronizado ?? this.sincronizado,
      fechaSincronizacion: fechaSincronizacion ?? this.fechaSincronizacion,
      idServidor: idServidor ?? this.idServidor,
      fechaCreacionLocal: fechaCreacionLocal ?? this.fechaCreacionLocal,
      intentos: intentos ?? this.intentos,
      ultimoIntento: ultimoIntento ?? this.ultimoIntento,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RegistroDespliegue(id: $id, estado: $estado, operadorId: $operadorId, fechaHora: $fechaHora, centroEmpadronamiento: $centroEmpadronamientoId, sincronizado: $sincronizado)';
  }

  // Método para verificar si es igual a otro registro
  bool isEqualTo(RegistroDespliegue other) {
    return fechaHora == other.fechaHora &&
        operadorId == other.operadorId &&
        estado == other.estado &&
        latitud == other.latitud &&
        longitud == other.longitud &&
        centroEmpadronamientoId == other.centroEmpadronamientoId;
  }

  // ✅ NUEVO: Método para validar que el registro esté completo
  bool isValid() {
    return fechaHora.isNotEmpty &&
        operadorId > 0 &&
        centroEmpadronamientoId != null &&
        centroEmpadronamientoId! > 0 &&
        latitud.isNotEmpty &&
        longitud.isNotEmpty;
  }

  // ✅ NUEVO: Método para obtener detalles de validación
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (fechaHora.isEmpty) errors.add('fechaHora está vacío');
    if (operadorId <= 0) errors.add('operadorId inválido');
    if (centroEmpadronamientoId == null || centroEmpadronamientoId! <= 0) {
      errors.add('centroEmpadronamiento está vacío o es 0');
    }
    if (latitud.isEmpty) errors.add('latitud está vacío');
    if (longitud.isEmpty) errors.add('longitud está vacío');

    return errors;
  }
}
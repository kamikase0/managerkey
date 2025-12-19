// lib/models/reporte_diario_local.dart
import 'package:flutter/material.dart';

class ReporteDiarioLocal {
  int? id;
  int? idServer;
  String contadorInicialR;
  String contadorFinalR;
  int saltosenR;
  String contadorR;
  String contadorInicialC;
  String contadorFinalC;
  int saltosenC;
  String contadorC;
  String fechaReporte;
  String? observaciones;
  String? incidencias;
  String estado;
  int idOperador;
  int? estacionId;
  String? nroEstacion;
  DateTime fechaCreacion;
  DateTime? fechaSincronizacion;
  String? observacionC;
  String? observacionR;
  int? centroEmpadronamiento;
  bool sincronizar;

  ReporteDiarioLocal({
    this.id,
    this.idServer,
    required this.contadorInicialR,
    required this.contadorFinalR,
    required this.saltosenR,
    required this.contadorR,
    required this.contadorInicialC,
    required this.contadorFinalC,
    required this.saltosenC,
    required this.contadorC,
    required this.fechaReporte,
    this.observaciones,
    this.incidencias,
    required this.estado,
    required this.idOperador,
    this.estacionId,
    this.nroEstacion,
    required this.fechaCreacion,
    this.fechaSincronizacion,
    this.observacionC,
    this.observacionR,
    this.centroEmpadronamiento,
    this.sincronizar = true,
  });

  // Método toLocalMap para guardar en base de datos SQLite
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'id_server': idServer,
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'saltosen_r': saltosenR,
      'contador_r': contadorR,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'saltosen_c': saltosenC,
      'contador_c': contadorC,
      'fecha_reporte': fechaReporte,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'estado': estado,
      'id_operador': idOperador,
      'estacion_id': estacionId,
      'nro_estacion': nroEstacion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
      'observacion_c': observacionC,
      'observacion_r': observacionR,
      'centro_empadronamiento': centroEmpadronamiento,
      // CAMBIO: La columna 'sincronizar' debe estar en el mapa para guardarse
      'sincronizar': sincronizar ? 1 : 0,
    };
  }

  // Método para enviar al API (Sin cambios, ya estaba bien)
  Map<String, dynamic> toApiJson() {
    return {
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'saltosenR': saltosenR,
      'contador_r': int.tryParse(contadorR) ?? 0,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'saltosenC': saltosenC,
      'contador_c': int.tryParse(contadorC) ?? 0,
      'fecha_reporte': fechaReporte,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'operador': idOperador,
      if (estacionId != null) 'estacion': estacionId,
      if (nroEstacion != null) 'nro_estacion': nroEstacion,
      if (observacionC != null) 'observacionC': observacionC,
      if (observacionR != null) 'observacionR': observacionR,
      if (centroEmpadronamiento != null) 'centro_empadronamiento': centroEmpadronamiento,

      'estado': 'ENVIO REPORTE',
      'sincronizar': sincronizar ? 1 : 0, // CAMBIO: Usar 1 para 'true'
    };
  }

  // Métodos para cambiar estado
  void marcarComoSincronizado(int serverId, DateTime fechaSincronizacion) {
    idServer = serverId;
    estado = 'sincronizado';
    this.fechaSincronizacion = fechaSincronizacion;
    sincronizar = false;
  }

  void marcarComoPendiente() {
    estado = 'pendiente';
    fechaSincronizacion = null;
  }

  void marcarComoFallido() {
    estado = 'fallido';
  }

  // Factory constructor para crear una instancia desde un mapa de la BD
  factory ReporteDiarioLocal.fromLocalMap(Map<String, dynamic> map) {
    return ReporteDiarioLocal(
      id: map['id'],
      idServer: map['id_server'],
      contadorInicialR: map['contador_inicial_r'] ?? '',
      contadorFinalR: map['contador_final_r'] ?? '',
      saltosenR: map['saltosen_r'] ?? 0,
      contadorR: map['contador_r']?.toString() ?? '0',
      contadorInicialC: map['contador_inicial_c'] ?? '',
      contadorFinalC: map['contador_final_c'] ?? '',
      saltosenC: map['saltosen_c'] ?? 0,
      contadorC: map['contador_c']?.toString() ?? '0',
      fechaReporte: map['fecha_reporte'] ?? '',
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      estado: map['estado'] ?? 'pendiente',
      idOperador: map['id_operador'] ?? 0,
      estacionId: map['estacion_id'],
      nroEstacion: map['nro_estacion'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      fechaSincronizacion: map['fecha_sincronizacion'] != null ? DateTime.parse(map['fecha_sincronizacion']) : null,
      observacionC: map['observacion_c'],
      observacionR: map['observacion_r'],
      centroEmpadronamiento: map['centro_empadronamiento'],
      // CAMBIO: Leer 'sincronizar' como un entero (0 o 1)
      sincronizar: map['sincronizar'] == 1,
    );
  }

  // Getters para verificar estado
  bool get isPendiente => estado == 'pendiente';
  bool get isSincronizado => estado == 'sincronizado';
  bool get isFallido => estado == 'fallido';

  /// Factory constructor para crear una instancia desde un mapa de la API.
  factory ReporteDiarioLocal.fromApiMap(Map<String, dynamic> map) {
    return ReporteDiarioLocal(
      idServer: map['id'],
      contadorInicialR: map['contador_inicial_r'] ?? '',
      contadorFinalR: map['contador_final_r'] ?? '',
      // CAMBIO: Usar snake_case para coincidir con el JSON de la API
      saltosenR: map['saltosen_r'] ?? 0,
      contadorR: (map['registro_r'] ?? 0).toString(),
      contadorInicialC: map['contador_inicial_c'] ?? '',
      contadorFinalC: map['contador_final_c'] ?? '',
      // CAMBIO: Usar snake_case para coincidir con el JSON de la API
      saltosenC: map['saltosen_c'] ?? 0,
      contadorC: (map['registro_c'] ?? 0).toString(),
      fechaReporte: map['fecha_reporte'] ?? DateTime.now().toIso8601String(),
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      estado: 'sincronizado', // Siempre es 'sincronizado' si viene de la API
      idOperador: map['operador'],
      estacionId: map['estacion'],
      fechaCreacion: DateTime.tryParse(map['fecha_registro'] ?? '') ?? DateTime.now(),
      fechaSincronizacion: DateTime.tryParse(map['fecha_registro'] ?? '') ?? DateTime.now(),
      centroEmpadronamiento: map['centro_empadronamiento'],
      sincronizar: false,
    );
  }
}

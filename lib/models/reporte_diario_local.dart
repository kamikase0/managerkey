// lib/models/reporte_diario_local.dart
import 'package:flutter/material.dart';
import 'package:manager_key/models/reporte_diario_historial.dart';


// lib/models/reporte_diario_local.dart
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
    };
  }

  // Método para enviar al API
  Map<String, dynamic> toApiJson() {
    return {
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'saltosen_r': saltosenR,
      'contador_r': int.tryParse(contadorR) ?? 0,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'saltosen_c': saltosenC,
      'contador_c': int.tryParse(contadorC) ?? 0,
      'fecha_reporte': fechaReporte,
      'observaciones': observaciones,
      'incidencias': incidencias,
      'operador': idOperador,
      if (estacionId != null) 'estacion': estacionId,
      if (nroEstacion != null) 'nro_estacion': nroEstacion,
      if (observacionC != null) 'observacion_c': observacionC,
      if (observacionR != null) 'observacion_r': observacionR,
      if (centroEmpadronamiento != null) 'centro_empadronamiento': centroEmpadronamiento,
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

  // --- AÑADIR ESTE MÉTODO ---
  // Factory constructor para crear una instancia desde un mapa de la BD
  factory ReporteDiarioLocal.fromLocalMap(Map<String, dynamic> map) {
    return ReporteDiarioLocal(
      id: map['id'],
      idServer: map['id_server'],
      contadorInicialR: map['contador_inicial_r'],
      contadorFinalR: map['contador_final_r'],
      saltosenR: map['saltosen_r'],
      contadorR: map['contador_r'],
      contadorInicialC: map['contador_inicial_c'],
      contadorFinalC: map['contador_final_c'],
      saltosenC: map['saltosen_c'],
      contadorC: map['contador_c'],
      fechaReporte: map['fecha_reporte'],
      observaciones: map['observaciones'],
      incidencias: map['incidencias'],
      estado: map['estado'],
      idOperador: map['id_operador'],
      estacionId: map['estacion_id'],
      nroEstacion: map['nro_estacion'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      fechaSincronizacion: map['fecha_sincronizacion'] != null ? DateTime.parse(map['fecha_sincronizacion']) : null,
      observacionC: map['observacion_c'],
      observacionR: map['observacion_r'],
      centroEmpadronamiento: map['centro_empadronamiento'],
      sincronizar: map['estado'] == 'pendiente', // Se deduce del estado
    );
  }

  // Getters para verificar estado
  bool get isPendiente => estado == 'pendiente';
  bool get isSincronizado => estado == 'sincronizado';
  bool get isFallido => estado == 'fallido';
}
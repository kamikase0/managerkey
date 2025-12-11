// lib/models/reporte_diario_historial.dart
import 'package:flutter/material.dart';

enum EstadoSincronizacion {
  pendiente,
  sincronizado,
  fallido,
}

extension EstadoSincronizacionExtension on EstadoSincronizacion {
  String get displayName {
    switch (this) {
      case EstadoSincronizacion.pendiente:
        return 'Pendiente';
      case EstadoSincronizacion.sincronizado:
        return 'Sincronizado';
      case EstadoSincronizacion.fallido:
        return 'Error';
    }
  }

  Color get color {
    switch (this) {
      case EstadoSincronizacion.pendiente:
        return Colors.orange;
      case EstadoSincronizacion.sincronizado:
        return Colors.green;
      case EstadoSincronizacion.fallido:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case EstadoSincronizacion.pendiente:
        return Icons.cloud_upload;
      case EstadoSincronizacion.sincronizado:
        return Icons.cloud_done;
      case EstadoSincronizacion.fallido:
        return Icons.cloud_off;
    }
  }
}

class ReporteDiarioHistorial {
  final int? id; // ID local
  final int? idServer; // ID del servidor
  final String fechaReporte;
  final String contadorInicialC;
  final String contadorFinalC;
  final String contadorC;
  final String contadorInicialR;
  final String contadorFinalR;
  final String contadorR;
  final String? incidencias;
  final String? observaciones;
  final DateTime fechaCreacion;
  final DateTime? fechaSincronizacion;
  final EstadoSincronizacion estadoSincronizacion;
  final int idOperador;
  final int idEstacion;
  final int? centroEmpadronamiento;
  final String? observacionC;
  final String? observacionR;
  final int saltosenC;
  final int saltosenR;

  ReporteDiarioHistorial({
    this.id,
    this.idServer,
    required this.fechaReporte,
    required this.contadorInicialC,
    required this.contadorFinalC,
    required this.contadorC,
    required this.contadorInicialR,
    required this.contadorFinalR,
    required this.contadorR,
    this.incidencias,
    this.observaciones,
    required this.fechaCreacion,
    this.fechaSincronizacion,
    required this.estadoSincronizacion,
    required this.idOperador, // ✅ Añadir estos parámetros
    required this.idEstacion,  // ✅ Añadir estos parámetros
    this.centroEmpadronamiento,
    this.observacionC,
    this.observacionR,
    required this.saltosenC,
    required this.saltosenR,
    // ✅ Eliminar los parámetros incorrectos:
    // required int operador,
    // required int estacion,
    // required bool sincronizar,
    // required int synced,
  });

  factory ReporteDiarioHistorial.fromJson(Map<String, dynamic> json) {
    return ReporteDiarioHistorial(
      idServer: json['id'],
      fechaReporte: json['fecha_reporte'] ?? '',
      contadorInicialC: json['contador_inicial_c'] ?? '',
      contadorFinalC: json['contador_final_c'] ?? '',
      contadorC: (json['registro_c'] ?? 0).toString(),
      contadorInicialR: json['contador_inicial_r'] ?? '',
      contadorFinalR: json['contador_final_r'] ?? '',
      contadorR: (json['registro_r'] ?? 0).toString(),
      incidencias: json['incidencias'],
      observaciones: json['observaciones'],
      fechaCreacion: DateTime.parse(json['fecha_registro'] ?? DateTime.now().toIso8601String()),
      estadoSincronizacion: EstadoSincronizacion.sincronizado,
      idOperador: json['operador'] ?? 0,
      idEstacion: json['estacion'] ?? 0,
      centroEmpadronamiento: json['centro_empadronamiento'],
      observacionC: json['observacionC'],
      observacionR: json['observacionR'],
      saltosenC: json['saltosenC'] ?? 0,
      saltosenR: json['saltosenR'] ?? 0,
    );
  }

  factory ReporteDiarioHistorial.fromLocal(Map<String, dynamic> map) {
    return ReporteDiarioHistorial(
      id: map['id'],
      idServer: map['id_server'],
      fechaReporte: map['fecha_reporte'],
      contadorInicialC: map['contador_inicial_c'],
      contadorFinalC: map['contador_final_c'],
      contadorC: map['contador_c'],
      contadorInicialR: map['contador_inicial_r'],
      contadorFinalR: map['contador_final_r'],
      contadorR: map['contador_r'],
      incidencias: map['incidencias'],
      observaciones: map['observaciones'],
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'])
          : null,
      estadoSincronizacion: _parseEstado(map['estado']),
      idOperador: map['id_operador'],
      idEstacion: map['estacion_id'] ?? 0,
      centroEmpadronamiento: map['centro_empadronamiento'],
      observacionC: map['observacionC'],
      observacionR: map['observacionR'],
      saltosenC: map['saltosen_c'] ?? 0,
      saltosenR: map['saltosen_r'] ?? 0,
    );
  }

  static EstadoSincronizacion _parseEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'sincronizado':
        return EstadoSincronizacion.sincronizado;
      case 'fallido':
        return EstadoSincronizacion.fallido;
      default:
        return EstadoSincronizacion.pendiente;
    }
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'id_server': idServer,
      'fecha_reporte': fechaReporte,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'contador_c': contadorC,
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'contador_r': contadorR,
      'incidencias': incidencias,
      'observaciones': observaciones,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
      'estado': estadoSincronizacion.toString().split('.').last,
      'id_operador': idOperador,
      'estacion_id': idEstacion,
      'centro_empadronamiento': centroEmpadronamiento,
      'observacionC': observacionC,
      'observacionR': observacionR,
      'saltosen_c': saltosenC,
      'saltosen_r': saltosenR,
    };
  }
}
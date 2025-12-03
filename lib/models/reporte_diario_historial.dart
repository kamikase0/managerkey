// lib/models/reporte_diario_historial.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReporteDiarioHistorial {
  final int? id;
  final String fechaReporte;
  final int registrosC;
  final int registrosR;
  final String? observaciones;
  final String? nombreEstacion;
  final EstadoSincronizacion estadoSincronizacion;
  final DateTime? fechaCreacion;
  final DateTime? fechaSincronizacion;

  ReporteDiarioHistorial({
    this.id,
    required this.fechaReporte,
    required this.registrosC,
    required this.registrosR,
    this.observaciones,
    this.nombreEstacion,
    required this.estadoSincronizacion,
    this.fechaCreacion,
    this.fechaSincronizacion,
  });

  factory ReporteDiarioHistorial.fromJson(Map<String, dynamic> json) {
    return ReporteDiarioHistorial(
      id: json['id'] as int?,
      fechaReporte: json['fecha_reporte'] ?? json['fechaReporte'] ?? '',
      registrosC: (json['registros_c'] ?? json['registrosC'] ?? 0) as int,
      registrosR: (json['registros_r'] ?? json['registrosR'] ?? 0) as int,
      observaciones: json['observaciones'] as String?,
      nombreEstacion: json['nombre_estacion'] ?? json['nombreEstacion'] as String?,
      estadoSincronizacion: _parseEstadoSincronizacion(json['estado'] ?? json['estado_sincronizacion']),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'] as String)
          : null,
      fechaSincronizacion: json['fecha_sincronizacion'] != null
          ? DateTime.parse(json['fecha_sincronizacion'] as String)
          : null,
    );
  }

  static EstadoSincronizacion _parseEstadoSincronizacion(dynamic estado) {
    if (estado == null) return EstadoSincronizacion.pendiente;

    final estadoStr = estado.toString().toLowerCase();
    if (estadoStr.contains('sincronizado') || estadoStr == '1' || estadoStr == 'true') {
      return EstadoSincronizacion.sincronizado;
    } else if (estadoStr.contains('fallido') || estadoStr.contains('error')) {
      return EstadoSincronizacion.fallido;
    } else {
      return EstadoSincronizacion.pendiente;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'fecha_reporte': fechaReporte,
      'registros_c': registrosC,
      'registros_r': registrosR,
      'observaciones': observaciones,
      'nombre_estacion': nombreEstacion,
      'estado_sincronizacion': estadoSincronizacion.toString().split('.').last,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
    };
  }
}

enum EstadoSincronizacion {
  sincronizado,
  pendiente,
  fallido,
}

// Para facilitar la conversión de estado
extension EstadoSincronizacionExtension on EstadoSincronizacion {
  String get displayName {
    switch (this) {
      case EstadoSincronizacion.sincronizado:
        return 'Sincronizado';
      case EstadoSincronizacion.pendiente:
        return 'Pendiente';
      case EstadoSincronizacion.fallido:
        return 'Fallido';
    }
  }

  Color get color {
    switch (this) {
      case EstadoSincronizacion.sincronizado:
        return Colors.green;
      case EstadoSincronizacion.pendiente:
        return Colors.orange;
      case EstadoSincronizacion.fallido:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case EstadoSincronizacion.sincronizado:
        return Icons.cloud_done;
      case EstadoSincronizacion.pendiente:
        return Icons.cloud_upload;
      case EstadoSincronizacion.fallido:
        return Icons.cloud_off;
    }
  }
}

// // models/reporte_diario_historial.dart
//
// class ReporteDiarioHistorial {
//   final int? id;
//   final String fechaReporte;
//   final String contadorInicialC;
//   final String contadorFinalC;
//   final String contadorC;
//   final String contadorInicialR;
//   final String contadorFinalR;
//   final String contadorR;
//   final String? incidencias;
//   final String? observaciones;
//   final int operador;
//   final int estacion;
//   final String estado;
//   final bool sincronizar;
//   final int synced;
//   final String? updatedAt;
//   final String? observacionC;
//   final String? observacionR;
//   final int saltosenC;
//   final int saltosenR;
//   final int? centroEmpadronamiento;
//
//   ReporteDiarioHistorial({
//     this.id,
//     required this.fechaReporte,
//     required this.contadorInicialC,
//     required this.contadorFinalC,
//     required this.contadorC,
//     required this.contadorInicialR,
//     required this.contadorFinalR,
//     required this.contadorR,
//     this.incidencias,
//     this.observaciones,
//     required this.operador,
//     required this.estacion,
//     this.estado = 'TRANSMITIDO',
//     this.sincronizar = true,
//     this.synced = 0,
//     this.updatedAt,
//     this.observacionC,
//     this.observacionR,
//     this.saltosenC = 0,
//     this.saltosenR = 0,
//     this.centroEmpadronamiento,
//   });
//
//   // Constructor desde JSON de API
//   factory ReporteDiarioHistorial.fromJson(Map<String, dynamic> json) {
//     return ReporteDiarioHistorial(
//       id: json['id'],
//       fechaReporte: json['fecha_reporte'] ?? '',
//       contadorInicialC: json['contador_inicial_c']?.toString() ?? '',
//       contadorFinalC: json['contador_final_c']?.toString() ?? '',
//       contadorC: json['contador_c']?.toString() ?? '',
//       contadorInicialR: json['contador_inicial_r']?.toString() ?? '',
//       contadorFinalR: json['contador_final_r']?.toString() ?? '',
//       contadorR: json['contador_r']?.toString() ?? '',
//       incidencias: json['incidencias'],
//       observaciones: json['observaciones'],
//       operador: json['operador'] ?? 0,
//       estacion: json['estacion'] ?? 0,
//       estado: json['estado'] ?? 'TRANSMITIDO',
//       sincronizar: json['sincronizar'] ?? true,
//       synced: json['synced'] ?? 1, // Los de API vienen sincronizados
//       updatedAt: json['updated_at'],
//       observacionC: json['observacionC'],
//       observacionR: json['observacionR'],
//       saltosenC: json['saltosenC'] ?? 0,
//       saltosenR: json['saltosenR'] ?? 0,
//       centroEmpadronamiento: json['centro_empadronamiento'],
//     );
//   }
//
//   // Constructor desde base de datos local
//   factory ReporteDiarioHistorial.fromDb(Map<String, dynamic> map) {
//     return ReporteDiarioHistorial(
//       id: map['id'],
//       fechaReporte: map['fecha_reporte'] ?? '',
//       contadorInicialC: map['contador_inicial_c']?.toString() ?? '',
//       contadorFinalC: map['contador_final_c']?.toString() ?? '',
//       contadorC: map['contador_c']?.toString() ?? '',
//       contadorInicialR: map['contador_inicial_r']?.toString() ?? '',
//       contadorFinalR: map['contador_final_r']?.toString() ?? '',
//       contadorR: map['contador_r']?.toString() ?? '',
//       incidencias: map['incidencias'],
//       observaciones: map['observaciones'],
//       operador: map['operador'] ?? 0,
//       estacion: map['estacion'] ?? 0,
//       estado: map['estado'] ?? 'TRANSMITIDO',
//       sincronizar: (map['sincronizar'] ?? 1) == 1,
//       synced: map['synced'] ?? 0,
//       updatedAt: map['updated_at'],
//       observacionC: map['observacionC'],
//       observacionR: map['observacionR'],
//       saltosenC: map['saltosenC'] ?? 0,
//       saltosenR: map['saltosenR'] ?? 0,
//       centroEmpadronamiento: map['centro_empadronamiento'],
//     );
//   }
//
//   // Convertir a Map para la base de datos
//   Map<String, dynamic> toDbMap() {
//     return {
//       'fecha_reporte': fechaReporte,
//       'contador_inicial_c': contadorInicialC,
//       'contador_final_c': contadorFinalC,
//       'contador_c': contadorC,
//       'contador_inicial_r': contadorInicialR,
//       'contador_final_r': contadorFinalR,
//       'contador_r': contadorR,
//       'incidencias': incidencias,
//       'observaciones': observaciones,
//       'operador': operador,
//       'estacion': estacion,
//       'estado': estado,
//       'sincronizar': sincronizar ? 1 : 0,
//       'synced': synced,
//       'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
//       'observacionC': observacionC,
//       'observacionR': observacionR,
//       'saltosenC': saltosenC,
//       'saltosenR': saltosenR,
//       'centro_empadronamiento': centroEmpadronamiento,
//     };
//   }
//
//   // Convertir a JSON para API
//   Map<String, dynamic> toApiJson() {
//     return {
//       'fecha_reporte': fechaReporte,
//       'contador_inicial_c': contadorInicialC,
//       'contador_final_c': contadorFinalC,
//       'contador_c': contadorC,
//       'contador_inicial_r': contadorInicialR,
//       'contador_final_r': contadorFinalR,
//       'contador_r': contadorR,
//       'incidencias': incidencias,
//       'observaciones': observaciones,
//       'operador': operador,
//       'estacion': estacion,
//       'estado': estado,
//       'sincronizar': sincronizar,
//       'synced': synced,
//       'updated_at': updatedAt,
//       'observacionC': observacionC,
//       'observacionR': observacionR,
//       'saltosenC': saltosenC,
//       'saltosenR': saltosenR,
//       'centro_empadronamiento': centroEmpadronamiento,
//     };
//   }
// }
//

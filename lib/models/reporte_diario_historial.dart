// lib/models/reporte_diario_historial.dart - VERSIÓN ACTUALIZADA
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReporteDiarioHistorial {
  final int? id;
  final String fechaReporte;
  final String contadorInicialC;
  final String contadorFinalC;
  final String contadorC;
  final String contadorInicialR;
  final String contadorFinalR;
  final String contadorR;
  final String? incidencias;
  final String? observaciones;
  final int operador;
  final int estacion;
  final EstadoSincronizacion estadoSincronizacion;
  final bool sincronizar;
  final int synced;
  final DateTime? fechaCreacion;
  final DateTime? fechaSincronizacion;
  final String? observacionC;
  final String? observacionR;
  final int saltosenC;
  final int saltosenR;
  final int? centroEmpadronamiento;

  ReporteDiarioHistorial({
    this.id,
    required this.fechaReporte,
    required this.contadorInicialC,
    required this.contadorFinalC,
    required this.contadorC,
    required this.contadorInicialR,
    required this.contadorFinalR,
    required this.contadorR,
    this.incidencias,
    this.observaciones,
    required this.operador,
    required this.estacion,
    required this.estadoSincronizacion,
    this.sincronizar = true,
    this.synced = 0,
    this.fechaCreacion,
    this.fechaSincronizacion,
    this.observacionC,
    this.observacionR,
    this.saltosenC = 0,
    this.saltosenR = 0,
    this.centroEmpadronamiento,
  });

  // Constructor desde JSON de API
  factory ReporteDiarioHistorial.fromJson(Map<String, dynamic> json) {
    return ReporteDiarioHistorial(
      id: json['id'] as int?,
      fechaReporte: json['fecha_reporte'] ?? '',
      contadorInicialC: json['contador_inicial_c']?.toString() ?? '',
      contadorFinalC: json['contador_final_c']?.toString() ?? '',
      contadorC: (json['registro_c'] ?? 0).toString(),
      contadorInicialR: json['contador_inicial_r']?.toString() ?? '',
      contadorFinalR: json['contador_final_r']?.toString() ?? '',
      contadorR: (json['registro_r'] ?? 0).toString(),
      incidencias: json['incidencias'] as String?,
      observaciones: json['observaciones'] as String?,
      operador: json['operador'] ?? 0,
      estacion: json['estacion'] ?? 0,
      estadoSincronizacion: _parseEstadoSincronizacion(json['estado']),
      sincronizar: json['sincronizar'] ?? true,
      synced: json['synced'] ?? 1, // Los de API vienen sincronizados
      fechaCreacion: json['fecha_registro'] != null
          ? DateTime.parse(json['fecha_registro'] as String)
          : null,
      fechaSincronizacion: json['fecha_sincronizacion'] != null
          ? DateTime.parse(json['fecha_sincronizacion'] as String)
          : null,
      observacionC: json['observacionC'] as String?,
      observacionR: json['observacionR'] as String?,
      saltosenC: json['saltosenC'] ?? 0,
      saltosenR: json['saltosenR'] ?? 0,
      centroEmpadronamiento: json['centro_empadronamiento'] as int?,
    );
  }

  // Constructor desde base de datos local
  factory ReporteDiarioHistorial.fromDb(Map<String, dynamic> map) {
    return ReporteDiarioHistorial(
      id: map['id'] as int?,
      fechaReporte: map['fecha_reporte'] ?? '',
      contadorInicialC: map['contador_inicial_c']?.toString() ?? '',
      contadorFinalC: map['contador_final_c']?.toString() ?? '',
      contadorC: map['contador_c']?.toString() ?? '',
      contadorInicialR: map['contador_inicial_r']?.toString() ?? '',
      contadorFinalR: map['contador_final_r']?.toString() ?? '',
      contadorR: map['contador_r']?.toString() ?? '',
      incidencias: map['incidencias'] as String?,
      observaciones: map['observaciones'] as String?,
      operador: map['operador'] ?? 0,
      estacion: map['estacion'] ?? 0,
      estadoSincronizacion: _parseEstadoSincronizacion(map['estado']),
      sincronizar: (map['sincronizar'] ?? 1) == 1,
      synced: map['synced'] ?? 0,
      fechaCreacion: map['fecha_creacion'] != null
          ? DateTime.parse(map['fecha_creacion'] as String)
          : null,
      fechaSincronizacion: map['fecha_sincronizacion'] != null
          ? DateTime.parse(map['fecha_sincronizacion'] as String)
          : null,
      observacionC: map['observacionC'] as String?,
      observacionR: map['observacionR'] as String?,
      saltosenC: map['saltosenC'] ?? 0,
      saltosenR: map['saltosenR'] ?? 0,
      centroEmpadronamiento: map['centro_empadronamiento'] as int?,
    );
  }

  static EstadoSincronizacion _parseEstadoSincronizacion(dynamic estado) {
    if (estado == null) return EstadoSincronizacion.pendiente;

    final estadoStr = estado.toString().toLowerCase();
    if (estadoStr.contains('sincronizado') ||
        estadoStr == '1' ||
        estadoStr == 'true' ||
        estadoStr.contains('envio reporte')) {
      return EstadoSincronizacion.sincronizado;
    } else if (estadoStr.contains('fallido') || estadoStr.contains('error')) {
      return EstadoSincronizacion.fallido;
    } else {
      return EstadoSincronizacion.pendiente;
    }
  }

  // Convertir a Map para la base de datos
  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'fecha_reporte': fechaReporte,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'contador_c': contadorC,
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'contador_r': contadorR,
      'incidencias': incidencias,
      'observaciones': observaciones,
      'operador': operador,
      'estacion': estacion,
      'estado': estadoSincronizacion.displayName,
      'sincronizar': sincronizar ? 1 : 0,
      'synced': synced,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'fecha_sincronizacion': fechaSincronizacion?.toIso8601String(),
      'observacionC': observacionC,
      'observacionR': observacionR,
      'saltosenC': saltosenC,
      'saltosenR': saltosenR,
      'centro_empadronamiento': centroEmpadronamiento,
    };
  }

  // Convertir a JSON para API
  Map<String, dynamic> toApiJson() {
    return {
      'fecha_reporte': fechaReporte,
      'contador_inicial_c': contadorInicialC,
      'contador_final_c': contadorFinalC,
      'contador_c': contadorC,
      'contador_inicial_r': contadorInicialR,
      'contador_final_r': contadorFinalR,
      'contador_r': contadorR,
      'incidencias': incidencias,
      'observaciones': observaciones,
      'operador': operador,
      'estacion': estacion,
      'estado': estadoSincronizacion.displayName,
      'sincronizar': sincronizar,
      'synced': synced,
      'updated_at': fechaCreacion?.toIso8601String(),
      'observacionC': observacionC,
      'observacionR': observacionR,
      'saltosenC': saltosenC,
      'saltosenR': saltosenR,
      'centro_empadronamiento': centroEmpadronamiento,
    };
  }

  // Getters para compatibilidad
  int get registrosC => int.tryParse(contadorC) ?? 0;
  int get registrosR => int.tryParse(contadorR) ?? 0;
  String? get nombreEstacion => null; // Este campo no viene en el JSON
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
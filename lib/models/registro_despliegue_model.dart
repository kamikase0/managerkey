class RegistroDespliegue {
  final int? id;
  final String destino;
  final String? latitudDespliegue;
  final String? longitudDespliegue;
  final String? latitudLlegada;
  final String? longitudLlegada;
  final String estado;
  final bool fueDesplegado;
  final bool llegoDestino;
  final String fechaHoraSalida;
  final String? fechaHoraLlegada;
  final int operadorId;
  final String? observaciones;
  final bool sincronizar;

  RegistroDespliegue({
    this.id,
    required this.destino,
    this.latitudDespliegue,
    this.longitudDespliegue,
    this.latitudLlegada,
    this.longitudLlegada,
    required this.estado,
    required this.fueDesplegado,
    required this.llegoDestino,
    required this.fechaHoraSalida,
    this.fechaHoraLlegada,
    required this.operadorId,
    this.observaciones,
    required this.sincronizar,
  });

  // Convertir a JSON para enviar al servidor
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'destino': destino,
      'estado': estado,
      'fue_desplegado': fueDesplegado,
      'llego_destino': llegoDestino,
      'fecha_hora_salida': fechaHoraSalida,
      'operador': operadorId,
      'sincronizar': sincronizar,
    };

    // Añadir campos de despliegue si existen
    if (latitudDespliegue != null) {
      json['latitud_despliegue'] = latitudDespliegue;
    }
    if (longitudDespliegue != null) {
      json['longitud_despliegue'] = longitudDespliegue;
    }

    // Añadir campos de llegada si existen
    if (latitudLlegada != null) {
      json['latitud_llegada'] = latitudLlegada;
    }
    if (longitudLlegada != null) {
      json['longitud_llegada'] = longitudLlegada;
    }

    // Campos opcionales
    if (fechaHoraLlegada != null) {
      json['fecha_hora_llegada'] = fechaHoraLlegada;
    }
    if (observaciones != null && observaciones!.isNotEmpty) {
      json['observaciones'] = observaciones;
    }

    return json;
  }

  // Crear desde JSON del servidor
  factory RegistroDespliegue.fromJson(Map<String, dynamic> json) {
    return RegistroDespliegue(
      id: json['id'],
      destino: json['destino'] ?? '',
      latitudDespliegue: json['latitud_despliegue'],
      longitudDespliegue: json['longitud_despliegue'],
      latitudLlegada: json['latitud_llegada'],
      longitudLlegada: json['longitud_llegada'],
      estado: json['estado'] ?? 'TRANSMITIDO',
      fueDesplegado: json['fue_desplegado'] ?? false,
      llegoDestino: json['llego_destino'] ?? false,
      fechaHoraSalida: json['fecha_hora_salida'] ?? '',
      fechaHoraLlegada: json['fecha_hora_llegada'],
      operadorId: json['operador'] ?? 0,
      observaciones: json['observaciones'],
      sincronizar: json['sincronizar'] ?? false,
    );
  }

  // Para base de datos local - SOLO guarda los campos necesarios
  Map<String, dynamic> toMap() {
    return {
      'destino': destino,
      'latitud_despliegue': latitudDespliegue,
      'longitud_despliegue': longitudDespliegue,
      'latitud_llegada': latitudLlegada,
      'longitud_llegada': longitudLlegada,
      'estado': estado,
      'fue_desplegado': fueDesplegado ? 1 : 0,
      'llego_destino': llegoDestino ? 1 : 0,
      'fecha_hora_salida': fechaHoraSalida,
      'fecha_hora_llegada': fechaHoraLlegada,
      'operador_id': operadorId,
      'observaciones': observaciones ?? '',
      'sincronizar': sincronizar ? 1 : 0,
    };
  }

  factory RegistroDespliegue.fromMap(Map<String, dynamic> map) {
    return RegistroDespliegue(
      id: map['id'],
      destino: map['destino'] ?? '',
      latitudDespliegue: map['latitud_despliegue'],
      longitudDespliegue: map['longitud_despliegue'],
      latitudLlegada: map['latitud_llegada'],
      longitudLlegada: map['longitud_llegada'],
      estado: map['estado'] ?? 'TRANSMITIDO',
      fueDesplegado: map['fue_desplegado'] == 1,
      llegoDestino: map['llego_destino'] == 1,
      fechaHoraSalida: map['fecha_hora_salida'] ?? '',
      fechaHoraLlegada: map['fecha_hora_llegada'],
      operadorId: map['operador_id'] ?? 0,
      observaciones: map['observaciones'],
      sincronizar: map['sincronizar'] == 1,
    );
  }

  RegistroDespliegue copyWith({
    int? id,
    String? destino,
    String? latitudDespliegue,
    String? longitudDespliegue,
    String? latitudLlegada,
    String? longitudLlegada,
    String? estado,
    bool? fueDesplegado,
    bool? llegoDestino,
    String? fechaHoraSalida,
    String? fechaHoraLlegada,
    int? operadorId,
    String? observaciones,
    bool? sincronizar,
  }) {
    return RegistroDespliegue(
      id: id ?? this.id,
      destino: destino ?? this.destino,
      latitudDespliegue: latitudDespliegue ?? this.latitudDespliegue,
      longitudDespliegue: longitudDespliegue ?? this.longitudDespliegue,
      latitudLlegada: latitudLlegada ?? this.latitudLlegada,
      longitudLlegada: longitudLlegada ?? this.longitudLlegada,
      estado: estado ?? this.estado,
      fueDesplegado: fueDesplegado ?? this.fueDesplegado,
      llegoDestino: llegoDestino ?? this.llegoDestino,
      fechaHoraSalida: fechaHoraSalida ?? this.fechaHoraSalida,
      fechaHoraLlegada: fechaHoraLlegada ?? this.fechaHoraLlegada,
      operadorId: operadorId ?? this.operadorId,
      observaciones: observaciones ?? this.observaciones,
      sincronizar: sincronizar ?? this.sincronizar,
    );
  }
}


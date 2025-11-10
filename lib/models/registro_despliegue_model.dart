class RegistroDespliegue {
  final int? id;
  final String destino;
  final String latitudDespliegue;
  final String longitudDespliegue;
  final String latitudLlegada;
  final String longitudLlegada;
  final String estado;
  final bool sincronizar;
  final String observaciones;
  final bool fueDesplegado;
  final String fechaHoraSalida;
  final bool llegoDestino;
  final String fechaHoraLlegada;
  final int operador;

  RegistroDespliegue({
    this.id,
    required this.destino,
    required this.latitudDespliegue,
    required this.longitudDespliegue,
    required this.latitudLlegada,
    required this.longitudLlegada,
    required this.estado,
    required this.sincronizar,
    required this.observaciones,
    required this.fueDesplegado,
    required this.fechaHoraSalida,
    required this.llegoDestino,
    required this.fechaHoraLlegada,
    required this.operador,
  });

  Map<String, dynamic> toJson() => {
    "destino": destino,
    "latitud_despliegue": latitudDespliegue,
    "longitud_despliegue": longitudDespliegue,
    "latitud_llegada": latitudLlegada,
    "longitud_llegada": longitudLlegada,
    "estado": estado,
    "sincronizar": sincronizar,
    "observaciones": observaciones,
    "fue_desplegado": fueDesplegado,
    "fecha_hora_salida": fechaHoraSalida,
    "llego_destino": llegoDestino,
    "fecha_hora_llegada": fechaHoraLlegada,
    "operador": operador,
  };
}

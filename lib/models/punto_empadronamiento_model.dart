class PuntoEmpadronamiento {
  final int id;
  final String provincia;
  final String puntoEmpadronamiento;

  PuntoEmpadronamiento({
    required this.id,
    required this.provincia,
    required this.puntoEmpadronamiento,
  });

  factory PuntoEmpadronamiento.fromJson(Map<String, dynamic> json) {
    return PuntoEmpadronamiento(
      id: json['id'],
      provincia: json['provincia'],
      // ✅ CORREGIDO: Usar el nombre correcto del campo JSON
      puntoEmpadronamiento: json['punto_de_empadronamiento'], // ❌ ANTES: punto_empadronamiento
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provincia': provincia,
      'punto_de_empadronamiento': puntoEmpadronamiento, // ✅ CORREGIDO
    };
  }

  @override
  String toString() {
    return 'PuntoEmpadronamiento{id: $id, provincia: $provincia, puntoEmpadronamiento: $puntoEmpadronamiento}';
  }
}
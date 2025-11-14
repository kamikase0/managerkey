class User {
  final int id;
  final String username;
  final String email;
  final List<String> groups;
  final bool isStaff;
  final bool isActive;
  final Operador? operador;
  final Coordinador? coordinador;


  User({
    required this.id,
    required this.username,
    required this.email,
    required this.groups,
    this.isStaff = false,
    this.isActive = true,
    this.operador,
    this.coordinador,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      groups: List<String>.from(json['groups'] ?? []),
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? true,
      operador: json['operador'] != null ? Operador.fromJson(json['operador']) : null,
      coordinador: json['coordinador'] != null ? Coordinador.fromJson(json['coordinador']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'groups': groups,
      'is_staff': isStaff,
      'is_active': isActive,
      'operador': operador?.toJson(),
      'coordinador': coordinador?.toJson(),
    };
  }

  // ✅ Getter para grupo principal
  String get primaryGroup => groups.isNotEmpty ? groups.first : 'operador';

  // ✅ Getter para tipo de operador
  String? get tipoOperador => operador?.tipoOperador;

  // ✅ Getter para id_operador
  int? get idOperador => operador?.idOperador;

  // ✅ Getter para determinar si es operador rural
  bool get isOperadorRural => operador?.tipoOperador == 'Operador Rural';

  // ✅ Getter para determinar si es operador urbano
  bool get isOperadorUrbano => operador?.tipoOperador == 'Operador Urbano';
}

class Operador {
  final int idOperador;
  final int idEstacion;
  final int nroEstacion;
  final String tipoOperador;
  final Ruta ruta;

  Operador({
    required this.idOperador,
    required this.idEstacion,
    required this.nroEstacion,
    required this.tipoOperador,
    required this.ruta,
  });

  factory Operador.fromJson(Map<String, dynamic> json) {
    return Operador(
      idOperador: json['id_operador'] ?? 0,
      idEstacion: json['id_estacion'] ?? 0,
      nroEstacion: json['nro_estacion'] ?? 0,
      tipoOperador: json['tipo_operador'] ?? '',
      ruta: json['ruta'] != null ? Ruta.fromJson(json['ruta']) : Ruta(id: 0, nombre: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_operador': idOperador,
      'id_estacion': idEstacion,
      'nro_estacion': nroEstacion,
      'tipo_operador': tipoOperador,
      'ruta': ruta.toJson(),
    };
  }
}

class Ruta {
  final int id;
  final String nombre;

  Ruta({
    required this.id,
    required this.nombre,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    return Ruta(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }
}

class Coordinador {
  final int? idCoordinador;

  Coordinador({
    this.idCoordinador,
  });

  factory Coordinador.fromJson(Map<String, dynamic> json) {
    return Coordinador(
      idCoordinador: json['id_coordinador'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_coordinador': idCoordinador,
    };
  }
}
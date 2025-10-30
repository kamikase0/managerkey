// models/user_model.dart
class User {
  final int id;
  final String username;
  final String email;
  final bool isStaff;
  final bool isActive;
  final List<String> groups;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.isStaff,
    required this.isActive,
    required this.groups,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isStaff: json['is_staff'],
      isActive: json['is_active'],
      groups: List<String>.from(json['groups']),
    );
  }

  String get primaryGroup => groups.isNotEmpty ? groups.first : 'operador';

  // Getter para nombre formateado
  String get displayName {
    final nameParts = username.split('_');
    final formattedName = nameParts.map((part) =>
    part[0].toUpperCase() + part.substring(1)
    ).join(' ');
    return formattedName;
  }

  // Getter para rol formateado
  String get roleDisplay {
    if (groups.isEmpty) return 'Usuario';

    final role = groups.first;
    switch (role) {
      case 'operador':
        return 'Operador Rural';
      case 'soporte':
        return 'Soporte Técnico';
      case 'coordinador':
        return 'Coordinador';
      default:
        return 'Usuario';
    }
  }

  // Getter para email display (si está vacío mostrar mensaje)
  String get emailDisplay {
    return email.isNotEmpty ? email : 'No tiene email registrado';
  }

  // Getter para mensaje de bienvenida personalizado
  String get welcomeMessage {
    final role = groups.isNotEmpty ? groups.first : 'operador';
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Buenos días';
    } else if (hour < 18) {
      greeting = 'Buenas tardes';
    } else {
      greeting = 'Buenas noches';
    }

    switch (role) {
      case 'operador':
        return '$greeting, $displayName. Listo para comenzar sus rutas.';
      case 'soporte':
        return '$greeting, $displayName. ¿En qué podemos ayudarte hoy?';
      case 'coordinador':
        return '$greeting, $displayName. Revisemos el estado de las operaciones.';
      default:
        return '$greeting, $displayName.';
    }
  }
}
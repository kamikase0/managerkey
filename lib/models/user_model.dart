class User {
  final int id;
  final String username;
  final String email;
  final List<String> groups;
  final bool isStaff;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.groups,
    this.isStaff = false,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      groups: List<String>.from(json['groups'] ?? []),
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  // ✅ Necesario para guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'groups': groups,
      'is_staff': isStaff,
      'is_active': isActive,
    };
  }

  // Helper para obtener el rol principal
  String get primaryGroup => groups.isNotEmpty ? groups.first : 'operador';
}

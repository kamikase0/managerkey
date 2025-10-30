// widgets/sidebar.dart
import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final String activeView;
  final Function(String) onViewChanged;
  final String userGroup;

  const Sidebar({
    Key? key,
    required this.activeView,
    required this.onViewChanged,
    required this.userGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final menuItems = {
      'operador': [
        {'id': 'operador', 'label': 'Vista Operador', 'icon': Icons.dashboard},
        {'id': 'salida_ruta', 'label': 'Salida de Ruta', 'icon': Icons.exit_to_app},
      ],
      'soporte': [
        {'id': 'soporte', 'label': 'Vista Soporte', 'icon': Icons.support}
      ],
      'coordinador': [
        {'id': 'coordinador', 'label': 'Vista Coordinador', 'icon': Icons.manage_accounts}
      ],
    };

    final currentMenu = menuItems[userGroup] ?? [];

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[700],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Panel de Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userGroup.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final item in currentMenu)
                  ListTile(
                    leading: Icon(item['icon'] as IconData),
                    title: Text(item['label'] as String),
                    selected: activeView == item['id'],
                    selectedTileColor: Colors.blue[50],
                    onTap: () => onViewChanged(item['id'] as String),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
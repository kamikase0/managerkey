import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final String activeView;
  final Function(String) onViewChanged;
  final String userGroup;
  final String tipoOperador;
  final bool isOperadorRural;

  const Sidebar({
    Key? key,
    required this.activeView,
    required this.onViewChanged,
    required this.userGroup,
    required this.tipoOperador,
    required this.isOperadorRural,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Manager Key',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userGroup,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  tipoOperador,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Menú para Operador Rural
          if (isOperadorRural) ...[
            _buildMenuItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              value: 'operador',
              isActive: activeView == 'operador',
              onTap: onViewChanged,
            ),
            _buildMenuItem(
              icon: Icons.play_circle_outline,
              label: 'Salida de Ruta',
              value: 'salida_ruta',
              isActive: activeView == 'salida_ruta',
              onTap: onViewChanged,
            ),
            _buildMenuItem(
              icon: Icons.flag,
              label: 'Llegada de Ruta',
              value: 'llegada_ruta',
              isActive: activeView == 'llegada_ruta',
              onTap: onViewChanged,
            ),
            _buildMenuItem(
              icon: Icons.assessment,
              label: 'Reporte Diario',
              value: 'reporte_diario',
              isActive: activeView == 'reporte_diario',
              onTap: onViewChanged,
            ),
            _buildMenuItem(
              icon: Icons.history,
              label: 'Histórico de Reportes',
              value: 'historial_reportes',
              isActive: activeView == 'historial_reportes',
              onTap: onViewChanged,
            ),
          ]
          // Menú para Operador Urbano
          else if (userGroup.toLowerCase().contains('operador')) ...[
            _buildMenuItem(
              icon: Icons.assessment,
              label: 'Reporte Diario',
              value: 'reporte_diario',
              isActive: activeView == 'reporte_diario',
              onTap: onViewChanged,
            ),
            _buildMenuItem(
              icon: Icons.history,
              label: 'Histórico de Reportes',
              value: 'historial_reportes',
              isActive: activeView == 'historial_reportes',
              onTap: onViewChanged,
            ),
          ]
          // Menú para Soporte
          else if (userGroup.toLowerCase().contains('soporte')) ...[
              _buildMenuItem(
                icon: Icons.help_outline,
                label: 'Soporte',
                value: 'soporte',
                isActive: activeView == 'soporte',
                onTap: onViewChanged,
              ),
            ]
            // Menú para Técnico
            else if (userGroup.toLowerCase().contains('tecnico')) ...[
                _buildMenuItem(
                  icon: Icons.inbox,
                  label: 'Recepción',
                  value: 'recepcion',
                  isActive: activeView == 'recepcion',
                  onTap: onViewChanged,
                ),
              ]
              // Menú para Coordinador
              else if (userGroup.toLowerCase().contains('coordinador')) ...[
                  _buildMenuItem(
                    icon: Icons.group,
                    label: 'Coordinador',
                    value: 'coordinador',
                    isActive: activeView == 'coordinador',
                    onTap: onViewChanged,
                  ),
                ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required Function(String) onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? Colors.blue.shade700 : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.blue.shade700 : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      selectedTileColor: Colors.blue.shade50,
      onTap: () => onTap(value),
    );
  }
}
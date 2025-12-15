// lib/widgets/sidebar.dart (ACTUALIZADO)
import 'package:flutter/material.dart';
// La importación de reporte_historial_view no se está usando, se puede eliminar si no es necesaria.
import '../views/operador/historial_reportes_diarios_view.dart';
// import '../views/operador/reporte_historial_view.dart';

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
                  'Empadronamiento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Muestra el tipo de operador si existe, si no, el grupo.
                  tipoOperador.isNotEmpty ? tipoOperador : userGroup,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                // Solo muestra el grupo si es diferente al tipo de operador
                if (tipoOperador.isNotEmpty && tipoOperador != userGroup)
                  Text(
                    userGroup,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // ⭐ --- OPCIÓN DE INICIO / BIENVENIDA (Común para todos) ---
          _buildMenuItem(
            icon: Icons.home,
            label: 'Inicio',
            value: 'bienvenida',
            isActive: activeView == 'bienvenida',
            onTap: onViewChanged,
          ),

          // ✅ --- MENÚ PARA USUARIO LOGÍSTICO ---
          if (tipoOperador.toLowerCase() == 'logistico') ...[
            _buildMenuItem(
              icon: Icons.flag,
              label: 'Llegada a Destino',
              value: 'llegada_ruta',
              isActive: activeView == 'llegada_ruta',
              onTap: onViewChanged,
            ),
          ]

          // ✅ --- MENÚ PARA OPERADOR RURAL ---
          else if (isOperadorRural) ...[
            _buildMenuItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              value: 'operador_view', // Cambiado a un valor único
              isActive: activeView == 'operador_view',
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
              label: 'Llegada a Ruta',
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
            _buildMenuItemWithNavigation(
              context: context,
              icon: Icons.history,
              label: 'Historial de Reportes',
              destination: const HistorialReportesDiariosView(),
            ),
          ]

          // ✅ --- MENÚ PARA OPERADOR URBANO (y otros operadores no rurales/logísticos) ---
          else if (userGroup.toLowerCase().contains('operador')) ...[
              _buildMenuItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                value: 'operador_view', // Cambiado a un valor único
                isActive: activeView == 'operador_view',
                onTap: onViewChanged,
              ),
              // La opción 'Salida de Ruta' se omite para el Urbano
              _buildMenuItem(
                icon: Icons.flag,
                label: 'Llegada a Ruta', // Opción añadida
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
              _buildMenuItemWithNavigation(
                context: context,
                icon: Icons.history,
                label: 'Historial de Reportes',
                destination: const HistorialReportesDiariosView(),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'v1.0.0', // Puedes cambiar esto por una variable si lo necesitas
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Los métodos _buildMenuItem y _buildMenuItemWithNavigation no necesitan cambios.
  // Tu implementación actual es perfecta.
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
        color: isActive ? Colors.blue.shade700 : Colors.grey[700],
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

  Widget _buildMenuItemWithNavigation({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget destination,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.grey[700],
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Cerrar drawer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => destination,
          ),
        );
      },
    );
  }
}

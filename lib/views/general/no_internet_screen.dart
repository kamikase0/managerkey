// views/no_internet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/enviroment.dart';

class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const NoInternetScreen({
    Key? key,
    this.onRetry,
    this.customMessage,
  }) : super(key: key);

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRetry() {
    HapticFeedback.lightImpact();
    widget.onRetry?.call();
  }

  void _copyServerUrl() {
    Clipboard.setData(ClipboardData(text: Enviroment.apiUrlDev));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('URL del servidor copiada: ${Enviroment.apiUrlDev}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono animado
              ScaleTransition(
                scale: _animation,
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 120,
                  color: Colors.grey[400],
                ),
              ),

              const SizedBox(height: 32),

              // Título
              Text(
                'Conexión Interrumpida',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Mensaje descriptivo
              Text(
                widget.customMessage ??
                    'No podemos establecer conexión con el servidor. '
                        'Por favor, verifica tu conexión a internet e intenta nuevamente.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Card con información del servidor
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Información del Servidor',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Host:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _copyServerUrl,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Enviroment.apiUrlDev,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontFamily: 'Monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botón de reintentar
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _handleRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar Conexión'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón secundario
              TextButton(
                onPressed: () {
                  // Aquí puedes agregar más opciones como:
                  // - Verificar configuración de red
                  // - Contactar al soporte
                  // - Etc.
                },
                child: const Text('Más opciones'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
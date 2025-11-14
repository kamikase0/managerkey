import 'package:flutter/cupertino.dart';
import 'package:manager_key/services/api_service.dart';
import 'package:manager_key/services/reporte_sync_service.dart';
import 'package:provider/provider.dart';

class ReporteHistorialView extends StatefulWidget{
  const ReporteHistorialView({Key? key}) : super(key: key);

  @override
  State<ReporteHistorialView> createState() => _ReporteHistorialViewState();
}
class _ReporteHistorialViewState extends State<ReporteHistorialView> {
  late ReporteSyncService _syncService;
  late ApiService _apiService;
  List<Map<String, dynamic>> _reportesServidor = [];


  @override
  void iniState(){
    super.initState();
    _syncService = context.read<ReporteSyncService>();
    _apiService = context.read<ApiService>();
}

}
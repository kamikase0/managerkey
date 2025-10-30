

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';

class ReportView extends StatefulWidget{
  const ReportView({Key? key}): super(key: key);

  @override
  _ReportViewState createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView>{
  final _formKey = GlobalKey<FormState>();
  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu'),
      ),
    );
  }
  
}
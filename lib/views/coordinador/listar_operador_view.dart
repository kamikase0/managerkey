
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ListarOperadorView extends StatefulWidget{
  const ListarOperadorView({Key? key}): super(key: key);

  @override
  _ListarOperadorViewState createState() => _ListarOperadorViewState();

}

class _ListarOperadorViewState extends State<ListarOperadorView>{

  @override
  void initState(){
    super.initState();

  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operadores'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }
}
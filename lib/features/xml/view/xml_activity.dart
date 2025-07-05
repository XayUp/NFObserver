import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/features/xml/widgets/xml_list_tile.dart';
import 'package:nfobserver/xml/nf_xml.dart';
import 'package:path/path.dart' as path;

class XMLActivity extends StatefulWidget {
  const XMLActivity({super.key});

  @override
  State<XMLActivity> createState() => _XMLActivityState();
}

class _XMLActivityState extends State<XMLActivity> {
  bool _isLoading = false;
  String _stateMessage = '';

  List<NFXML> _nfXmlListFuture = [];

  @override
  void initState() {
    super.initState();
    // Iniciamos o carregamento dos arquivos assim que a tela é criada.
    _refreshList();
  }

  void _refreshList() async {
    setState(() {
      _isLoading = true;
      _stateMessage = '';
      _nfXmlListFuture.clear();
    });

    final nfList = await _loadXmlFiles();
    setState(() => _nfXmlListFuture = nfList);

    setState(() {
      _isLoading = false;
    });
  }

  /// Carrega e processa os arquivos XML do diretório definido nas configurações.
  Future<List<NFXML>> _loadXmlFiles() async {
    final List<NFXML> nfList = [];
    final directoryPath = GlobalSettings.xmlPath;

    // Validação inicial do caminho.
    try {
      if (directoryPath.isEmpty) {
        // Lança um erro que será capturado pelo FutureBuilder.
        throw Exception("O caminho para os arquivos XML não foi configurado.");
      }

      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        throw Exception("O diretório '$directoryPath' não foi encontrado.");
      }

      // Filtra apenas arquivos com extensão .xml.
      final files = directory.listSync().whereType<File>().where(
        (file) => path.extension(file.path).toLowerCase() == '.xml',
      );

      for (final file in files) {
        // Usamos o método que criamos para fazer o parse do arquivo.
        setState(() {
          _stateMessage = "Lendo o arquivo XML: ${path.basename(file.path)}";
        });
        final nfXml = await NFXML.fromFile(file);
        if (nfXml != null) {
          nfList.add(nfXml);
        }
      }
    } catch (e) {
      setState(() {
        _stateMessage = "Erro ao carregar arquivos XML: ${e.toString().replaceFirst("Exception: ", '')}";
      });
      return [];
    }

    // Ordena a lista pela nota fiscal mais recente (maior número).
    nfList.sort((a, b) => b.nfNumber.compareTo(a.nfNumber));
    return nfList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notas Fiscais (XML)"),
      ),
      body: _nfXmlListFuture.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  Text(_stateMessage),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _nfXmlListFuture.length,
              itemBuilder: (context, index) => XMLListTile(nfXML: _nfXmlListFuture[index]),
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Total de arquivos", style: Theme.of(context).textTheme.titleSmall),
                  Text(_nfXmlListFuture.length.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _refreshList,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

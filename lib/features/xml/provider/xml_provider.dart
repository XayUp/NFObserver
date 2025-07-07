import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/models/xml/nf_xml.dart';
import 'package:path/path.dart' as path;

class XmlProvider with ChangeNotifier {
  bool _isLoading = false;
  List<NFXML> _nfXmlList = [];

  // Getters públicos para que a UI possa ler o estado
  bool get isLoading => _isLoading;
  List<NFXML> get nfXmlList => _nfXmlList;

  /// Carrega e processa os arquivos XML do diretório definido nas configurações.
  Future<void> refreshList({Function(String message, bool error)? statusCallback}) async {
    _isLoading = true;
    _nfXmlList.clear();
    notifyListeners(); // Notifica os widgets que o estado mudou (carregamento iniciado)

    try {
      final directoryPath = GlobalSettings.xmlPath;

      if (directoryPath.isEmpty) {
        statusCallback?.call("O caminho para os arquivos XML não foi configurado.", true);
      }

      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        statusCallback?.call("O diretório '$directoryPath' não foi encontrado.", true);
      }

      final files = directory.listSync().whereType<File>().where(
        (file) => path.extension(file.path).toLowerCase() == '.xml',
      );

      if (files.isEmpty) {
        statusCallback?.call("Nenhum arquivo .xml encontrado no diretório.", true);
      }

      for (final file in files) {
        notifyListeners();
        statusCallback?.call(path.basename(file.path), false);
        final nfXml = await NFXML.fromFile(file);
        if (nfXml != null) {
          _nfXmlList.add(nfXml);
        }
      }

      // Ordena a lista pela nota fiscal mais recente (maior número).
      _nfXmlList.sort((a, b) => b.nfNumber.compareTo(a.nfNumber));
    } catch (e) {
      statusCallback?.call("Erro: ${e.toString().replaceFirst("Exception: ", '')}", true);
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifica que o carregamento terminou (com sucesso ou erro)
    }
  }
}

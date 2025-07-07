import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

class NFXML {
  final int nfNumber;
  final String issueData;
  final String departureDate;
  final String emitName;
  final String emitFant;

  NFXML._({
    required this.nfNumber,
    required this.issueData,
    required this.departureDate,
    required this.emitName,
    required this.emitFant,
  });

  static Future<NFXML?> fromFile(File file) async {
    try {
      final fileContent = await file.readAsString();
      final document = XmlDocument.parse(fileContent);

      // A tag <ide> geralmente contém as informações de identificação da NF-e.
      final ideElement = document.findAllElements('ide').first;

      // Extrai os valores das tags específicas dentro de <ide>.
      // Usamos .innerText que é mais seguro e correto para obter o texto do elemento.
      final nfNumber = int.parse(ideElement.findElements('nNF').first.innerText);
      final issueData = ideElement.findElements('dhEmi').first.innerText; // Data de Emissão
      // A data de saída pode não existir, então usamos 'firstOrNull' e um valor padrão.
      final departureDate = ideElement.findElements('dhSaiEnt').firstOrNull?.innerText ?? 'Não informada';

      final emitElement = document.findAllElements('emit').first;

      final emitName = emitElement.findElements('xNome').first.innerText;
      // O nome fantasia também pode não existir.
      final emitFant = emitElement.findElements('xFant').firstOrNull?.innerText ?? '';

      return NFXML._(
        nfNumber: nfNumber,
        issueData: issueData,
        departureDate: departureDate,
        emitName: emitName,
        emitFant: emitFant,
      );
    } catch (e) {
      debugPrint("Occorreu um erro ao processar o arquivo XML: $e");
      // Retornamos null para indicar que o parse falhou para este arquivo.
      return null;
    }
  }
}

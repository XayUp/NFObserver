import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

class NFXML {
  final int nfNumber;
  final String? nfKey;
  final String path;
  final String issueData;
  final String departureDate;
  final String emitName;
  final String emitFant;
  final List<Map<String, String>>? paymentsDates;

  NFXML._({
    required this.nfNumber,
    required this.nfKey,
    required this.path,
    required this.issueData,
    required this.departureDate,
    required this.emitName,
    required this.emitFant,
    required this.paymentsDates,
  });

  static Future<NFXML?> fromFile(File file) async {
    try {
      final fileContent = await file.readAsString();
      final document = XmlDocument.parse(fileContent);

      // Obtém o elemento que contém a chave da nota
      final infNFe = document.findAllElements('infNFe').first;
      final idAttribute = infNFe.getAttributeNode('Id')?.innerText;
      String? nfKey;

      debugPrint("Verificando a chave da nota");
      if (idAttribute != null) {
        nfKey = idAttribute.replaceAll('NFe', '');
      }

      debugPrint("Verificando dados da nota");
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

      final cobrElement = infNFe.findAllElements('cobr').firstOrNull;
      final fatElement = cobrElement?.findAllElements('fat').firstOrNull;

      final cobrList = cobrElement == null ? null : <Map<String, String>>[];
      if (cobrList != null) {
        debugPrint("Verificando as faturas");
        if (fatElement != null) {
          final nFat = fatElement.getElement('nFat')?.innerText;
          final vOrig = fatElement.getElement('vOrig')?.innerText;
          final vDesc = fatElement.getElement('vDesc')?.innerText;
          final vLiq = fatElement.getElement('vLiq')?.innerText;
          final map = {
            if (nFat != null) "Fatura Nº: ": nFat,
            if (vOrig != null) "Valor original: ": vOrig,
            if (vDesc != null) "Valor com desconto: ": vDesc,
            if (vLiq != null) "Valor líquido: ": vLiq,
          };
          if (map.isNotEmpty) cobrList.add(map);
        }

        debugPrint("Verificando as duplicatas");
        final dupList = List.generate(
          cobrElement!.children.length,
          (index) {
            final xmlElement = (cobrElement.children[index] as XmlElement);
            if (xmlElement.localName == 'dup') {
              final nDup = xmlElement.getElement('nDup')?.innerText;
              final dVenc = xmlElement.getElement('dVenc')?.innerText;
              final vDup = xmlElement.getElement('vDup')?.innerText;
              return <String, String>{
                if (nDup != null) "Parcela Nº: ": nDup,
                if (dVenc != null) "Data de vencimento: ": dVenc,
                if (vDup != null) "Valor da duplicata: ": vDup,
              };
            }
          },
        );
        if (dupList.isNotEmpty) {
          dupList.sort((a, b) {
            if (a == null || b == null || !a.containsKey('Parcela') || !b.containsKey('Parcela')) return 0;
            final int aParcela = int.tryParse(a['Parcela'] ?? '') ?? 0;
            final int bParcela = int.tryParse(b['Parcela'] ?? '') ?? 0;
            return aParcela.compareTo(bParcela);
          });
          cobrList.addAll(dupList.whereType<Map<String, String>>());
        }
      }

      return NFXML._(
        nfNumber: nfNumber,
        nfKey: nfKey,
        path: file.path,
        issueData: issueData,
        departureDate: departureDate,
        emitName: emitName,
        emitFant: emitFant,
        paymentsDates: cobrList,
      );
    } catch (e) {
      debugPrint("Occorreu um erro ao processar o arquivo XML: $e");
      // Retornamos null para indicar que o parse falhou para este arquivo.
      return null;
    }
  }
}

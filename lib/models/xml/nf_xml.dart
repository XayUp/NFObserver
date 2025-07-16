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
      final idAttribute = infNFe.getAttributeNode('Id')?.value;
      String? nfKey;

      if (idAttribute != null) {
        nfKey = idAttribute.replaceAll('NFe', '');
      }

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
      final fatElement = infNFe.findAllElements('fat').firstOrNull;

      final cobrList = cobrElement == null ? null : <Map<String, String>>[];
      if (cobrList != null) {
        if (fatElement != null) {
          cobrList.add({
            "Número da fatura: ": fatElement.getElement('nFat')!.value!,
            "Valor original:": fatElement.getElement('vOrig')!.value!,
            if (fatElement.getElement('vDesc') != null) "Valor do desconto: ": fatElement.getElement('vDesc')!.value!,
            "Valor líquido: ": fatElement.getElement('vLiq')!.value!,
          });
          final dupList = List.generate(
            cobrElement!.children.length,
            (index) {
              final xmlElement = (cobrElement.children[index] as XmlElement);
              if (xmlElement.localName == 'dup') {
                return <String, String>{
                  "Parcela": xmlElement.getElement('nDup')!.value!,
                  "Data": xmlElement.getElement('dVenc')!.value!,
                  "Valor": xmlElement.getElement('vDup')!.value!,
                };
              }
            },
          );
          if (dupList.isNotEmpty) {
            dupList.sort((a, b) => int.tryParse(a!['Parcela']!)!.compareTo(int.tryParse(b!['Parcela']!)!));
            cobrList.addAll(dupList.whereType());
          }
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

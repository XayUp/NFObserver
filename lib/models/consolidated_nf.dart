import 'package:nfobserver/models/nf_doc/nf_doc.dart';
import 'package:nfobserver/models/xml/nf_xml.dart';

/// Descreve o status do cruzamento de dados entre o Documento e o XML.
enum CrossCheckStatus {
  complete, // Documento e XML correspondente foram encontrados.
  onlyDoc, // Apenas o Documento foi encontrado.
}

/// Descreve o status do processamento em segundo plano para um item.
enum ProcessingStatus {
  pending, // Ainda não foi processado (verificação de e-mail/XML).
  complete, // O processamento foi concluído para este item.
}

class ConsolidatedNF {
  /// O documento principal. Sempre existirá em um modelo consolidado.
  final NFDoc docData;

  /// Os dados do XML correspondente, se encontrado.
  final NFXML? xmlData;

  /// Indica se o documento foi marcado como "enviado" (verificado via e-mail).
  final bool isSent;

  /// O status do cruzamento de dados.
  final CrossCheckStatus crossCheckStatus;

  /// O status do processamento em segundo plano.
  final ProcessingStatus processingStatus;

  ConsolidatedNF({
    required this.docData,
    this.xmlData,
    required this.isSent,
    required this.processingStatus,
  }) : crossCheckStatus = (xmlData != null) ? CrossCheckStatus.complete : CrossCheckStatus.onlyDoc;

  /// Cria uma cópia desta instância, mas com os campos fornecidos substituídos.
  ConsolidatedNF copyWith({
    NFDoc? docData,
    NFXML? xmlData,
    bool? isSent,
    ProcessingStatus? processingStatus,
  }) {
    return ConsolidatedNF(
      docData: docData ?? this.docData,
      xmlData: xmlData ?? this.xmlData,
      isSent: isSent ?? this.isSent,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }
}

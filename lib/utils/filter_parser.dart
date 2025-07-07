import 'dart:convert';

import 'package:flutter/foundation.dart';

enum OperationType { contains, regex }

// ignore: constant_identifier_names
enum FileType {
  bonus,
  // ignore: constant_identifier_names
  fiscal_note,
  report,
  paid,
  unknow;

  String get displayName {
    return name.replaceAll("_", " ");
  }
}

class FilterParser {
  //{
  //  FILE_TYPE: "<NOME_DO_TIPO>",
  //  OPERATOR_TYPE : "<TIPO_OPERAÇÂO>",
  //  OCCURRENCE : "<OCORRÊNCIA>"
  //}
  static List<String> parseFilter(String filter) {
    try {
      Map<String, dynamic> filterMap = json.decode(filter);
      final String fileType = filterMap["FILE_TYPE"];
      final String operatorType = filterMap["OPERATOR_TYPE"];
      final String occurrence = filterMap["OCCURRENCE"];

      // Validação robusta e case-insensitive para garantir que os filtros funcionem
      final isFileTypeValid = FileType.values.any(
        (e) => e.name.toUpperCase() == fileType.toUpperCase(),
      );
      final isOperatorTypeValid = OperationType.values.any(
        (e) => e.name.toUpperCase() == operatorType.toUpperCase(),
      );

      if (fileType.isNotEmpty &&
          isFileTypeValid &&
          operatorType.isNotEmpty &&
          isOperatorTypeValid &&
          occurrence.isNotEmpty) {
        return [fileType, operatorType, occurrence];
      }
      // ignore: empty_catches
    } catch (e) {
      debugPrint("Invalid filter: $e");
    }
    return [];
  }

  static String serializeFilter(List<String> filter) {
    final Map<String, String> filterMap = {
      'FILE_TYPE': filter[0].toUpperCase(),
      'OPERATOR_TYPE': filter[1].toUpperCase(),
      'OCCURRENCE': filter[2], // Passe a string diretamente, sem tratamento especial.
    };
    return jsonEncode(filterMap);
  }
}

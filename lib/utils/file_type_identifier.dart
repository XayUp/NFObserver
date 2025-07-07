import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/utils/filter_parser.dart';

/// Uma classe utilitária para identificar o tipo de um arquivo com base nos filtros globais.
class FileTypeIdentifier {
  /// Retorna o [FileType] correspondente para um dado [fileName].
  ///
  /// Itera sobre os filtros definidos em [GlobalSettings.docTypeFilters],
  /// aplica a lógica (CONTAINS ou REGEX) e retorna o primeiro tipo correspondente.
  /// Se nenhuma regra corresponder, retorna [FileType.unknow].
  static FileType getFileType(String fileName) {
    final upperFileName = fileName.toUpperCase();

    for (var filterString in GlobalSettings.docTypeFilters) {
      final filterParts = FilterParser.parseFilter(filterString);
      if (filterParts.isEmpty) continue;

      final fileTypeString = filterParts[0];
      final operatorTypeString = filterParts[1];
      final occurrence = filterParts[2];

      final operationType = OperationType.values.firstWhere(
        (e) => e.name.toUpperCase() == operatorTypeString.toUpperCase(),
        // Este orElse não deve ser alcançado devido à validação do parser.
        orElse: () => OperationType.contains,
      );

      bool match = false;
      switch (operationType) {
        case OperationType.contains:
          match = upperFileName.contains(occurrence.toUpperCase());
          break;
        case OperationType.regex:
          try {
            match = RegExp(occurrence, caseSensitive: false).hasMatch(fileName);
          } catch (e) {
            // Regex inválido no filtro, ignora esta regra.
            match = false;
          }
          break;
      }

      if (match) {
        return FileType.values.firstWhere(
          (e) => e.name.toUpperCase() == fileTypeString.toUpperCase(),
          orElse: () => FileType.unknow,
        );
      }
    }
    return FileType.unknow;
  }
}

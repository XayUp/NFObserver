import 'package:flutter/foundation.dart';

/// Enum for the supported placeholders in the document name format.
enum DocNamePlaceholder {
  data,
  nome_fornecedor,
  numero_nf,
  // A special placeholder to ignore parts of the filename.
  ignorar,
}

/// A utility class to parse document filenames based on a user-defined format.
class DocNameParser {
  // A map of placeholders to their corresponding regex capture groups.
  static final Map<DocNamePlaceholder, String> _placeholderPatterns = {
    DocNamePlaceholder.data: '(.+)',
    DocNamePlaceholder.nome_fornecedor: '(.+)',
    DocNamePlaceholder.numero_nf: '(\\d+)',
    DocNamePlaceholder.ignorar: '(.*)',
  };

  /// Parses a [fileName] (without extension) based on a user-defined [format] string.
  ///
  /// Returns a map where keys are the placeholder names (e.g., "NUMERO_NF")
  /// and values are the extracted strings.
  ///
  /// Returns an empty map if the file name does not match the format.
  static Map<String, String> parse(String fileName, String format) {
    final result = <String, String>{};
    try {
      final (regex, placeholders) = _buildRegexFromFormat(format);
      final match = regex.firstMatch(fileName);

      if (match != null && match.groupCount == placeholders.length) {
        for (int i = 0; i < placeholders.length; i++) {
          final placeholder = placeholders[i];
          final value = match.group(i + 1) ?? '';
          // We don't add IGNORE to the final result map.
          if (placeholder != DocNamePlaceholder.ignorar) {
            result[placeholder.name.toUpperCase()] = value;
          }
        }
      }
    } catch (e) {
      debugPrint("Error parsing document name with format '$format': $e");
    }
    return result;
  }

  /// Converts a user-friendly format string into a [RegExp] and a list of placeholders.
  static (RegExp, List<DocNamePlaceholder>) _buildRegexFromFormat(String format) {
    final placeholderFinder = RegExp(r'<([A-Z_]+)>', caseSensitive: false);
    final placeholdersInOrder = <DocNamePlaceholder>[];
    final regexBuffer = StringBuffer('^');
    int lastMatchEnd = 0;

    for (final match in placeholderFinder.allMatches(format)) {
      if (match.start > lastMatchEnd) {
        regexBuffer.write(RegExp.escape(format.substring(lastMatchEnd, match.start)));
      }

      final placeholderName = match.group(1) ?? '';
      try {
        final placeholder = DocNamePlaceholder.values.firstWhere(
          (e) => e.name.toUpperCase() == placeholderName.toUpperCase(),
        );
        placeholdersInOrder.add(placeholder);
        regexBuffer.write(_placeholderPatterns[placeholder]);
      } catch (e) {
        regexBuffer.write(RegExp.escape(match.group(0)!));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < format.length) {
      regexBuffer.write(RegExp.escape(format.substring(lastMatchEnd)));
    }

    regexBuffer.write(r'$');
    return (RegExp(regexBuffer.toString()), placeholdersInOrder);
  }
}

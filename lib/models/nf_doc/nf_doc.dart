import 'dart:io';

import 'package:path/path.dart' as p;

class NFDoc {
  final File file;
  String? name;
  String? path;
  String? date;
  String? supplierName;

  NFDoc._({required this.file});

  /// Cria uma instância de NFDoc a partir de um arquivo.
  /// No futuro, você pode adicionar lógica aqui para validar o arquivo.
  static NFDoc fromFile(File file) {
    final doc = NFDoc._(file: file);
    doc.name = p.basename(file.path);
    doc.path = file.path;
    return doc;
  }
}

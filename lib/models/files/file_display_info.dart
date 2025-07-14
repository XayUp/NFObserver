import 'dart:io';

class FileDisplayInfo {
  final FileSystemEntity fileEntity; // Pode ser File ou Directory
  final DateTime modifiedDate;

  // O construtor lê a data de modificação uma vez
  FileDisplayInfo(this.fileEntity) : modifiedDate = fileEntity.statSync().modified;

  String get name => fileEntity.path.split(Platform.pathSeparator).last;
}

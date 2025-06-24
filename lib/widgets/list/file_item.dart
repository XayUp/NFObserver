import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileItem extends StatelessWidget {
  final File file;
  final bool isSent;
  final String Function(File file)? subtitleFilter;
  const FileItem({
    super.key,
    required this.file,
    required this.isSent,
    this.subtitleFilter,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        // Ação ao tocar no item. Apenas ter um onTap já habilita o efeito de clique.
        //debugPrint("Item tocado: ${p.basename(file.path)}");
      },
      leading: Icon(
        isSent ? Icons.check_circle : Icons.hourglass_top_rounded,
        color: isSent ? Colors.green : Colors.orange,
      ),
      title: Text(p.basename(file.path)),
      subtitle: Text(
        subtitleFilter?.call(file) ?? p.dirname(file.path),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

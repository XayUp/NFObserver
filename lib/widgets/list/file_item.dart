import 'package:flutter/material.dart';

class FileItem extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Icon? icon;
  const FileItem({super.key, this.title, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onTap: () {
          // Ação ao tocar no item. Apenas ter um onTap já habilita o efeito de clique.
          //debugPrint("Item tocado: ${p.basename(file.path)}");
        },
        leading: ((title == null || title!.isEmpty) && icon == null)
            ? Icon(Icons.insert_drive_file, color: Colors.amberAccent)
            : icon,
        title: Text(title ?? ""),
        subtitle: Text(
          subtitle ?? "",
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

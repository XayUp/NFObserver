import 'package:flutter/material.dart';
import 'package:nfobserver/models/consolidated_nf.dart';
import 'package:nfobserver/utils/file_type_identifier.dart';
import 'package:nfobserver/utils/filter_parser.dart';

class NFListTile extends StatelessWidget {
  final ConsolidatedNF nf;

  const NFListTile({super.key, required this.nf});

  /// Retorna um ícone e uma cor com base no tipo do documento.
  (IconData, Color) _getDocTypeVisuals(BuildContext context) {
    final fileType = FileTypeIdentifier.getFileType(nf.docData.name ?? '');

    switch (fileType) {
      case FileType.fiscal_note:
        return (Icons.receipt_long, Colors.orange.shade700);
      case FileType.bonus:
        return (Icons.star, Colors.amber.shade800);
      case FileType.report:
        return (Icons.analytics, Colors.blue.shade700);
      case FileType.paid:
        return (Icons.price_check, Colors.green.shade700);
      case FileType.unknow:
      default:
        return (Icons.description, Theme.of(context).colorScheme.onSurface.withOpacity(0.6));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (docIcon, docColor) = _getDocTypeVisuals(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            // 1. Ícone do Documento (Esquerda)
            CircleAvatar(
              backgroundColor: docColor.withOpacity(0.15),
              child: Icon(docIcon, color: docColor),
            ),
            const SizedBox(width: 16),

            // 2. Informações do Documento (Centro)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nf.docData.name ?? 'Nome indisponível',
                    style: textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (nf.xmlData?.emitName != null || nf.docData.supplierName != null) const SizedBox(height: 4),
                  Text(
                    nf.xmlData?.emitName ?? nf.docData.supplierName ?? '',
                    style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 3. Ícones de Status (Direita)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone de XML Presente
                Icon(
                  Icons.data_object,
                  color: nf.crossCheckStatus == CrossCheckStatus.complete ? Colors.green.shade600 : Colors.red.shade600,
                  size: 20,
                  semanticLabel: nf.crossCheckStatus == CrossCheckStatus.complete
                      ? 'XML Encontrado'
                      : 'XML não encontrado',
                ),
                const SizedBox(height: 8),
                // Ícone de Nota Enviada
                Icon(
                  Icons.outgoing_mail,
                  color: nf.isSent ? Colors.green.shade600 : Colors.red.shade600,
                  size: 20,
                  semanticLabel: nf.isSent ? 'Enviado' : 'Não enviado',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

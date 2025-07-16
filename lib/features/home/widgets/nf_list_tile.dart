import 'package:flutter/material.dart';
import 'package:nfobserver/models/consolidated_nf.dart';
import 'package:nfobserver/utils/file_type_identifier.dart';
import 'package:nfobserver/utils/filter_parser.dart';
import 'dart:math';

class NFListTile extends StatelessWidget {
  final ValueNotifier<bool> _expanded = ValueNotifier<bool>(false);
  final ConsolidatedNF nf;
  final BuildContext context;

  FileType _fileType = FileType.unknow;
  FileType get fileType => _fileType;

  NFListTile({super.key, required this.context, required this.nf});

  /// Retorna um ícone e uma cor com base no tipo do documento.
  (IconData, Color) _getDocTypeVisuals(BuildContext context) {
    _fileType = FileTypeIdentifier.getFileType(nf.docData.name ?? '');
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
        return (Icons.description, Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (docIcon, docColor) = _getDocTypeVisuals(context);
    final textTheme = Theme.of(context).textTheme;

    // Variaveis metricas
    final round = 8.0;
    final borderWidth = 2.0;

    return ValueListenableBuilder<bool>(
      valueListenable: _expanded,
      builder: (context, isExpanded, child) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(round)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: docColor.withValues(alpha: 0.15),
              child: Icon(docIcon, color: docColor),
            ),
            title: Text(
              nf.docData.name ?? 'Nome indisponível',
              style: textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              nf.xmlData?.emitName ?? nf.docData.supplierName ?? '',
              style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _buildStatusIcons(nf),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(round),
              side: BorderSide(width: borderWidth, color: Colors.green.shade400),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(round),
              side: BorderSide(width: borderWidth, color: Colors.transparent),
            ),
            children: [
              _buildExpandedContent(context),
            ],
            onExpansionChanged: (value) => _expanded.value = value,
          ),
        );
      },
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4 * 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Informações do documento
          _buildTitleRow('Informações do documento'),
          if (nf.docData.lastModification != null) _buildInfoRow('Número', nf.docData.lastModification!),
          if (nf.docData.path != null) _buildInfoRow('Caminho completo', nf.docData.path!),
          if (nf.docData.supplierName != null) _buildInfoRow('Fornecedor', nf.docData.supplierName!),
          //Informações do XML caso haja
          if (nf.xmlData != null) _buildTitleRow('Informações do XML'),
          if (nf.xmlData?.nfNumber != null) _buildInfoRow('Número da nota:', "${nf.xmlData!.nfNumber}"),
          if (nf.xmlData?.nfKey != null) _buildInfoRow("Chave da nota:", "${nf.xmlData!.nfKey}"),
          if (nf.xmlData?.path != null) _buildInfoRow('Caminho completo:', nf.xmlData!.path),
          if (nf.xmlData?.issueData != null) _buildInfoRow('Data de emissão:', nf.xmlData!.issueData),
          if (nf.xmlData?.departureDate != null) _buildInfoRow('Data/ de saída:', nf.xmlData!.departureDate),

          if (nf.xmlData?.paymentsDates != null) ...[
            _buildTitleRow("Cobranças"),
            _buildPaymentTable(nf.xmlData!.paymentsDates!),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentTable(List<Map<String, String>> payments) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: (payments.length / 3).ceil()),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        final keys = payment.keys;
        final children = keys.map((key) => _buildInfoRow(key, payment[key]!)).toList();

        return Column(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildTitleRow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStatusIcons(ConsolidatedNF nf) {
    final iconSize = 30.0;
    const horizontalPadding = 16.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.description, // Ou outro ícone que represente o status do XML
          color: nf.crossCheckStatus == CrossCheckStatus.complete
              ? Colors.green.shade600
              : _fileType != FileType.fiscal_note
              ? Theme.of(context).primaryColor
              : Colors.red.shade600,
          size: iconSize,
          semanticLabel: nf.crossCheckStatus == CrossCheckStatus.complete ? 'XML Encontrado' : 'XML não encontrado',
        ),
        const SizedBox(width: horizontalPadding),
        Icon(
          Icons.outgoing_mail,
          color: nf.isSent
              ? Colors.green.shade600
              : _fileType != FileType.fiscal_note
              ? Theme.of(context).primaryColor
              : Colors.red.shade600,
          size: iconSize,
          semanticLabel: nf.isSent ? 'Enviado' : 'Não enviado',
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nfobserver/models/consolidated_nf.dart';
import 'package:nfobserver/utils/file_type_identifier.dart';
import 'package:nfobserver/utils/filter_parser.dart';

/// A ListTile designed to display the consolidated status of a document (NFDoc).
class NFListTile extends StatelessWidget {
  final ConsolidatedNF nf;

  const NFListTile({super.key, required this.nf});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: _getLeadingIcon(context),
        title: Text(nf.docData.name ?? 'Documento sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_getSubtitle(context)),
        // Controla a cor do tile com base no status de envio.
        backgroundColor: nf.isSent ? Colors.green.withOpacity(0.05) : null,
        collapsedBackgroundColor: nf.isSent ? Colors.green.withOpacity(0.05) : null,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildExpandedContent(context),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle(BuildContext context) {
    if (nf.processingStatus == ProcessingStatus.pending) {
      return 'Verificando...';
    }

    final fileType = FileTypeIdentifier.getFileType(nf.docData.name ?? '');
    // Deixa a primeira letra maiúscula para uma melhor apresentação (ex: "Fiscal note")
    final fileTypeDisplayName = fileType.displayName[0].toUpperCase() + fileType.displayName.substring(1);

    String secondaryInfo;
    if (nf.xmlData != null) {
      final fantasyName = nf.xmlData!.emitFant;
      secondaryInfo = fantasyName.isNotEmpty ? fantasyName : nf.xmlData!.emitName;
    } else {
      secondaryInfo = 'XML não encontrado';
    }

    return '$fileTypeDisplayName • $secondaryInfo';
  }

  /// Retorna um ícone que representa o status de envio e a presença do XML.
  Widget _getLeadingIcon(BuildContext context) {
    // Se o processamento não estiver completo, mostra um indicador de progresso.
    if (nf.processingStatus == ProcessingStatus.pending) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
      );
    }

    final fileType = FileTypeIdentifier.getFileType(nf.docData.name ?? '');
    // A cor do ícone reflete o status de envio.
    Color iconColor;
    IconData iconData;
    switch (fileType) {
      case FileType.fiscal_note:
        iconData = Icons.receipt_long_outlined;
        iconColor = nf.isSent ? Colors.green : Colors.red;
        break;
      case FileType.bonus:
        iconData = Icons.card_giftcard_outlined;
        iconColor = Colors.orange;
        break;
      case FileType.report:
        iconData = Icons.analytics_outlined;
        iconColor = Colors.deepPurple;
        break;
      case FileType.paid:
        iconData = Icons.price_check_outlined;
        iconColor = Colors.lightGreen.shade900;
        break;
      case FileType.unknow:
        iconData = Icons.insert_drive_file_outlined;
        iconColor = Colors.grey;
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          iconData,
          color: iconColor,
          size: 40,
        ),
        if (nf.crossCheckStatus == CrossCheckStatus.complete)
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Theme.of(context).cardColor,
              child: Icon(Icons.description, size: 12, color: Colors.blue.shade600),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildExpandedContent(BuildContext context) {
    final List<Widget> children = [];

    // A seção do documento sempre será exibida.
    children.add(_buildSectionTitle(context, 'Dados do Documento'));
    children.add(_buildInfoRow(context, 'Arquivo:', nf.docData.name ?? 'N/A'));
    children.add(_buildInfoRow(context, 'Caminho:', nf.docData.path ?? 'N/A'));
    children.add(_buildInfoRow(context, 'Status:', nf.isSent ? 'Enviado' : 'Não Enviado'));
    children.add(
      _buildInfoRow(
        context,
        'Verificação:',
        nf.processingStatus == ProcessingStatus.complete ? 'Concluída' : 'Pendente',
      ),
    );

    if (nf.xmlData != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildSectionTitle(context, 'Dados do XML Correspondente'));
      children.add(_buildInfoRow(context, 'NF:', nf.xmlData!.nfNumber.toString()));
      children.add(_buildInfoRow(context, 'Emitente:', nf.xmlData!.emitName));
      children.add(_buildInfoRow(context, 'Emissão:', nf.xmlData!.issueData));
    }

    return children;
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text.rich(
        TextSpan(
          style: textTheme.bodyMedium,
          children: <TextSpan>[
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

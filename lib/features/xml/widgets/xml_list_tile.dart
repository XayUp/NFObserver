import 'package:flutter/material.dart';
import 'package:nfobserver/xml/nf_xml.dart';

class XMLListTile extends StatelessWidget {
  final NFXML nfXML;

  const XMLListTile({super.key, required this.nfXML});

  @override
  Widget build(BuildContext context) {
    // Usamos Card para dar um destaque visual melhor para cada item da lista.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(
          'NF: ${nfXML.nfNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(nfXML.emitFant.isNotEmpty ? nfXML.emitFant : nfXML.emitName),
        children: <Widget>[
          // Adicionamos um Padding para o conteúdo expandido não ficar colado nas bordas.
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(context, 'Emitente:', nfXML.emitName),
                _buildInfoRow(context, 'Data de Emissão:', nfXML.issueData),
                _buildInfoRow(context, 'Data de Saída/Entrada:', nfXML.departureDate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para criar as linhas de informação de forma padronizada.
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text.rich(
        TextSpan(
          style: textTheme.bodyMedium, // Usa o estilo de texto padrão do tema
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

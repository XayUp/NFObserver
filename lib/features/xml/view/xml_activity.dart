import 'package:flutter/material.dart';
import 'package:nfobserver/features/xml/provider/xml_provider.dart';
import 'package:nfobserver/features/xml/widgets/xml_list_tile.dart';
import 'package:provider/provider.dart';

class XMLActivity extends StatefulWidget {
  const XMLActivity({super.key});

  @override
  State<XMLActivity> createState() => _XMLActivityState();
}

class _XMLActivityState extends State<XMLActivity> {
  String _stateMessage = "";

  void stateCallback(message, error) {
    if (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      //setState(() {
      _stateMessage = message;
      //});
    }
  }

  @override
  void initState() {
    super.initState();
    // Garante que o provider seja acessado após a construção do widget.
    // Só carrega a lista se ela estiver vazia, para não recarregar toda vez
    // que o usuário entrar na tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<XmlProvider>(context, listen: false);
      if (provider.nfXmlList.isEmpty && !provider.isLoading) {
        provider.refreshList(
          statusCallback: stateCallback,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 'context.watch' faz com que o widget reconstrua sempre que 'notifyListeners' é chamado.
    final xmlProvider = context.watch<XmlProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notas Fiscais (XML)"),
      ),
      body: xmlProvider.nfXmlList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (xmlProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  Text(_stateMessage),
                ],
              ),
            )
          : ListView.builder(
              itemCount: xmlProvider.nfXmlList.length,
              itemBuilder: (context, index) => XMLListTile(nfXML: xmlProvider.nfXmlList[index]),
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    xmlProvider.isLoading ? "Lendo o seguinte arquivo:" : "Total de arquivos lidos:",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    xmlProvider.isLoading ? _stateMessage : xmlProvider.nfXmlList.length.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () => context.read<XmlProvider>().refreshList(
              statusCallback: stateCallback,
            ),
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/utils/filter_parser.dart';

class FormatSettingsActivity extends StatefulWidget {
  const FormatSettingsActivity({super.key});

  @override
  State<FormatSettingsActivity> createState() => _FormatSettingsActivityState();
}

class _FormatSettingsActivityState extends State<FormatSettingsActivity> {
  // A local copy of the formats to allow editing without saving immediately.
  late Map<String, List<String>> _docNameFormats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFormats();
  }

  void _loadFormats() {
    setState(() {
      // Create a deep copy to avoid modifying the original map from GlobalSettings directly.
      _docNameFormats = GlobalSettings.docNameFormats.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
      _isLoading = false;
    });
  }

  Future<void> _saveFormats() async {
    await GlobalSettings.setDocNameFormats(_docNameFormats);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formatos salvos com sucesso!')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _showRuleDialog({required String fileTypeKey, int? ruleIndex}) async {
    final isEditing = ruleIndex != null;
    final originalFormat = isEditing ? _docNameFormats[fileTypeKey]![ruleIndex] : '';
    final textController = TextEditingController(text: originalFormat);

    final newFormat = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Regra' : 'Adicionar Nova Regra'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Formato da Regra',
            hintText: '<DATA> - <NOME_FORNECEDOR> - NF <NUMERO_NF>',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newFormat != null && newFormat.isNotEmpty) {
      setState(() {
        if (isEditing) {
          _docNameFormats[fileTypeKey]![ruleIndex] = newFormat;
        } else {
          // If the file type doesn't have a list yet, create one.
          if (!_docNameFormats.containsKey(fileTypeKey)) {
            _docNameFormats[fileTypeKey] = [];
          }
          _docNameFormats[fileTypeKey]!.add(newFormat);
        }
      });
    }
  }

  void _deleteRule(String fileTypeKey, int ruleIndex) {
    setState(() {
      _docNameFormats[fileTypeKey]?.removeAt(ruleIndex);
    });
  }

  void _reorderRule(String fileTypeKey, int oldIndex, int newIndex) {
    setState(() {
      // This logic handles reordering when moving an item to a lower index.
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _docNameFormats[fileTypeKey]!.removeAt(oldIndex);
      _docNameFormats[fileTypeKey]!.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get all FileType values except 'unknow'
    final availableFileTypes = FileType.values.where((ft) => ft != FileType.unknow).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Formatos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salvar e Voltar',
            onPressed: _saveFormats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Space for FAB
              itemCount: availableFileTypes.length,
              itemBuilder: (context, index) {
                final fileType = availableFileTypes[index];
                final fileTypeKey = fileType.name.toUpperCase();
                final formatsForType = _docNameFormats[fileTypeKey] ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    title: Text(
                      fileType.displayName[0].toUpperCase() + fileType.displayName.substring(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${formatsForType.length} regra(s) definida(s)'),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: formatsForType.length,
                        itemBuilder: (context, ruleIndex) {
                          final format = formatsForType[ruleIndex];
                          return ListTile(
                            key: ValueKey('$fileTypeKey-$ruleIndex-$format'), // More robust key
                            leading: const Icon(Icons.drag_handle),
                            title: Text(format, style: Theme.of(context).textTheme.bodyMedium),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Editar',
                                  onPressed: () => _showRuleDialog(fileTypeKey: fileTypeKey, ruleIndex: ruleIndex),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Excluir',
                                  onPressed: () => _deleteRule(fileTypeKey, ruleIndex),
                                ),
                              ],
                            ),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          _reorderRule(fileTypeKey, oldIndex, newIndex);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: const Text('Adicionar nova regra'),
                        onTap: () => _showRuleDialog(fileTypeKey: fileTypeKey),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

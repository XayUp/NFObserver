import 'package:flutter/material.dart';
import 'package:nfobserver/features/app_routers.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/utils/filter_parser.dart';
import 'package:nfobserver/utils/theme_notifier.dart';
import 'package:provider/provider.dart';

class SettingsActivity extends StatelessWidget {
  const SettingsActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingActivityHome();
  }

  static List<String> getEssentialMailSettings() {
    return [
      if (GlobalSettings.analyzeFilesPath.isEmpty) "Diretório dos arquivos locais não configurado.",
      if (GlobalSettings.imapServer.isEmpty) "Servidor IMAP não configurado.",
      if (GlobalSettings.imapPort <= 0 || GlobalSettings.imapPort >= 65536) "Porta IMAP inválida.",
      if (GlobalSettings.mail.isEmpty) "Email não configurado.",
    ];
  }
}

class SettingActivityHome extends StatefulWidget {
  const SettingActivityHome({super.key});

  @override
  State<SettingActivityHome> createState() => _SettingActivityState();
}

class _SettingActivityState extends State<SettingActivityHome> {
  TextEditingController? _tmpTextController;

  @override
  void dispose() {
    _tmpTextController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Aparência',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ListTile(
            title: const Text("Tema"),
            onTap: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Alterne entre os temas"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('Padrão do Sistema'),
                      value: ThemeMode.system,
                      groupValue: themeNotifier.themeMode,
                      onChanged: (value) => {themeNotifier.setThemeMode(value!), Navigator.of(context).pop()},
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Claro'),
                      value: ThemeMode.light,
                      groupValue: themeNotifier.themeMode,
                      onChanged: (value) => {themeNotifier.setThemeMode(value!), Navigator.of(context).pop()},
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Escuro'),
                      value: ThemeMode.dark,
                      groupValue: themeNotifier.themeMode,
                      onChanged: (value) => {themeNotifier.setThemeMode(value!), Navigator.of(context).pop()},
                    ),
                  ],
                ),
                actions: [],
              ),
            ),
          ),
          ListTile(
            title: const Text("Filtro para ícones de arquivos"),
            subtitle: const Text("Filtro para definir os ícones na lista pelo tipo do arquivo com base no nome"),
            onTap: () {
              final valorController = TextEditingController();
              showDialog(
                context: context,
                builder: (context) {
                  OperationType? operationType;
                  FileType? fileType;

                  bool editFilter = false;
                  bool newFilter = false;

                  List<List<String>> filters = GlobalSettings.docTypeFilters
                      .map((filterStr) => FilterParser.parseFilter(filterStr))
                      .where((filter) => filter.isNotEmpty)
                      .toList();

                  //O filtro para edição
                  List<String>? filterToEdit;

                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter stateSetter) {
                      return AlertDialog(
                        title: Text(editFilter ? "Editar Filtro" : "Edite ou adicione filtros"),
                        content: !editFilter
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 500,
                                    height: 200,
                                    child: ListView.builder(
                                      itemCount: filters.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          title: Text(filters[index][0]),
                                          subtitle: Text(filters[index][2]),
                                          onTap: () => stateSetter(() {
                                            filterToEdit = filters[index];
                                            editFilter = true;
                                            valorController.text = filterToEdit![2];

                                            for (var tmpFileType in FileType.values) {
                                              if (filterToEdit![0].toLowerCase() == tmpFileType.name.toLowerCase()) {
                                                fileType = tmpFileType;
                                                break;
                                              }
                                            }
                                            for (var tmpOperatorType in OperationType.values) {
                                              if (filterToEdit![1].toLowerCase() ==
                                                  tmpOperatorType.name.toLowerCase()) {
                                                operationType = tmpOperatorType;
                                                break;
                                              }
                                            }
                                            operationType ??= OperationType.contains;
                                            fileType ??= FileType.unknow;
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: OperationType.values
                                        .map(
                                          (currentOperationType) => Expanded(
                                            child: RadioListTile<OperationType>(
                                              title: Text(currentOperationType.name.toUpperCase()),
                                              value: currentOperationType,
                                              groupValue: operationType,
                                              onChanged: (value) => stateSetter(() => operationType = value!),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: valorController,
                                          decoration: InputDecoration(
                                            //hintText: "Valor",
                                            labelText: "Valor",
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      for (var i = 0; i < FileType.values.length; i += 2)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: RadioListTile<FileType>(
                                                title: Text(FileType.values[i].name.replaceAll("_", " ").toUpperCase()),
                                                value: FileType.values[i],
                                                groupValue: fileType,
                                                onChanged: (value) => stateSetter(() => fileType = value!),
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                            if (i + 1 < FileType.values.length)
                                              Expanded(
                                                child: RadioListTile<FileType>(
                                                  title: Text(
                                                    FileType.values[i + 1].name.replaceAll("_", " ").toUpperCase(),
                                                  ),
                                                  value: FileType.values[i + 1],
                                                  groupValue: fileType,
                                                  onChanged: (value) => stateSetter(() => fileType = value!),
                                                  dense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                        actions: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!newFilter)
                                Expanded(
                                  child: Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          stateSetter(() {
                                            if (editFilter && !newFilter) {
                                              filters.remove(filterToEdit);
                                              valorController.text = "";
                                              filterToEdit = null;
                                              operationType = null;
                                              fileType = null;
                                              editFilter = false;
                                              newFilter = false;
                                            } else {
                                              filterToEdit = [
                                                (fileType = FileType.unknow).name.toUpperCase(),
                                                (operationType = OperationType.contains).name.toUpperCase(),
                                                valorController.text = "",
                                              ];
                                              editFilter = true;
                                              newFilter = true;
                                            }
                                          });
                                        },
                                        child: Text(editFilter && !newFilter ? "Remover" : "Adicionar"),
                                      ),
                                    ],
                                  ),
                                ),
                              TextButton(
                                onPressed: () => stateSetter(() {
                                  //Gravar informação
                                  if (editFilter) {
                                    filterToEdit![0] = fileType!.name.toUpperCase();
                                    filterToEdit![1] = operationType!.name.toUpperCase();
                                    filterToEdit![2] = valorController.text;

                                    if (newFilter) {
                                      filters.add(filterToEdit!);
                                      newFilter = false;
                                    }

                                    filterToEdit = null;
                                    //Atualiza o estado
                                    editFilter = !editFilter;
                                  } else {
                                    //Converter em um mapa JSON compatível e salvar em SharedPreferences
                                    GlobalSettings.docTypeFilters = filters
                                        .map((filter) => FilterParser.serializeFilter(filter))
                                        .toList();
                                    debugPrint(GlobalSettings.docTypeFilters.toString());
                                    Navigator.pop(context);
                                  }
                                }),
                                child: Text("Gravar"),
                              ),
                              TextButton(
                                onPressed: () => stateSetter(() {
                                  if (editFilter) {
                                    editFilter = !editFilter;
                                  } else {
                                    Navigator.pop(context);
                                  }
                                }),
                                child: Text("Cancelar"),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ).then((_) {
                valorController.dispose();
              });
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Diretórios',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ListTile(
            title: const Text("Diretório dos arquivos locais"),
            textColor: GlobalSettings.analyzeFilesPath.isNotEmpty ? null : Colors.red, // Cor do texto baseado no estado
            subtitle: const Text("Define em qual diretório estarão os arquivos para serem analisados"),
            onTap: () {
              // Ação ao tocar na opção de analisar arquivos
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Diretório"),
                    content: TextField(
                      decoration: const InputDecoration(hintText: "Digite o caminho do diretório"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.analyzeFilesPath),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.analyzeFilesPath = _tmpTextController?.text ?? "";
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text("Diretório dos XMLs"),
            textColor: GlobalSettings.xmlPath.isNotEmpty ? null : Colors.red, // Cor do texto baseado no estado
            subtitle: const Text("Define em qual diretório estarão os XMLs para serem analisados"),
            onTap: () {
              // Ação ao tocar na opção de analisar arquivos
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Diretório"),
                    content: TextField(
                      decoration: const InputDecoration(hintText: "Digite o caminho do diretório"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.xmlPath),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.xmlPath = _tmpTextController?.text ?? "";
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sincronização',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          ListTile(
            title: const Text("Servidor IMAP"),
            textColor: (GlobalSettings.imapServer.isNotEmpty) ? null : Colors.red,
            subtitle: const Text("Define o servidor IMAP para conexão"),
            onTap: () {
              // Ação ao tocar na opção de servidor IMAP
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Servidor IMAP"),
                    content: TextField(
                      decoration: const InputDecoration(hintText: "Digite o endereço do servidor IMAP"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.imapServer),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.imapServer = _tmpTextController?.text ?? ""; // Garante atribuição não-nula
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text("Porta IMAP"),
            textColor: ((GlobalSettings.imapPort > 0 && GlobalSettings.imapPort < 65536)) ? null : Colors.red,
            subtitle: const Text("Define a porta IMAP do servidor para conexão"),
            onTap: () {
              // Ação ao tocar na opção de porta IMAP
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar porta IMAP"),
                    content: TextField(
                      decoration: const InputDecoration(hintText: "Digite a porta IMAP"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.imapPort.toString()),
                      keyboardType: TextInputType.number,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.imapPort = _tmpTextController!.text.isNotEmpty
                              ? int.tryParse(_tmpTextController!.text) ?? 0
                              : 0;
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text("Email"),
            textColor: GlobalSettings.mail.isNotEmpty ? null : Colors.red,
            subtitle: const Text("Define o email do login"),
            onTap: () {
              // Ação ao tocar na opção de email
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Email"),
                    content: TextField(
                      decoration: const InputDecoration(hintText: "Digite seu email"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.mail),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.mail = _tmpTextController?.text ?? "";
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text("Senha"),
            textColor: GlobalSettings.password.isNotEmpty ? null : Colors.red,
            subtitle: const Text("Define a senha do login"),
            onTap: () {
              // Ação ao tocar na opção de senha
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Senha"),
                    content: TextField(
                      obscureText: true,
                      decoration: const InputDecoration(hintText: "Digite sua senha"),
                      controller: _tmpTextController = TextEditingController(text: GlobalSettings.password),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          // Atualiza o estado para refletir a nova senha
                          GlobalSettings.password = _tmpTextController?.text ?? "";
                          Navigator.of(context).pop();
                        }),
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Arquivos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.rule_folder_outlined),
            title: const Text('Gerenciar Formatos de Nomes'),
            subtitle: const Text('Defina como o app extrai dados dos nomes dos arquivos.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, AppRouters.formatSettings);
            },
          ),
        ],
      ),
    );
  }
}

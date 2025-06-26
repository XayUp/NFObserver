import 'package:flutter/material.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/utils/theme_notifier.dart';
import 'package:provider/provider.dart';

class SettingsActivity extends StatelessWidget {
  const SettingsActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingActivityHome();
  }

  static List<String> getEssentialMailSettings() {
    return [
      if (GlobalSettings.analyzeFilesPath.isEmpty)
        "Diretório dos arquivos locais não configurado.",
      if (GlobalSettings.imapServer.isEmpty) "Servidor IMAP não configurado.",
      if (GlobalSettings.imapPort <= 0 || GlobalSettings.imapPort >= 65536)
        "Porta IMAP inválida.",
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
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
                      onChanged: (value) => {
                        themeNotifier.setThemeMode(value!),
                        Navigator.of(context).pop(),
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Claro'),
                      value: ThemeMode.light,
                      groupValue: themeNotifier.themeMode,
                      onChanged: (value) => {
                        themeNotifier.setThemeMode(value!),
                        Navigator.of(context).pop(),
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Escuro'),
                      value: ThemeMode.dark,
                      groupValue: themeNotifier.themeMode,
                      onChanged: (value) => {
                        themeNotifier.setThemeMode(value!),
                        Navigator.of(context).pop(),
                      },
                    ),
                  ],
                ),
                actions: [],
              ),
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sincronização',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            title: const Text("Diretório dos arquivos locais"),
            textColor: GlobalSettings.analyzeFilesPath.isNotEmpty
                ? null
                : Colors.red, // Cor do texto baseado no estado
            subtitle: const Text(
              "Define em qual diretório estarão os arquivos para serem analisados",
            ),
            onTap: () {
              // Ação ao tocar na opção de analisar arquivos
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Diretório"),
                    content: TextField(
                      decoration: const InputDecoration(
                        hintText: "Digite o caminho do diretório",
                      ),
                      controller: _tmpTextController = TextEditingController(
                        text: GlobalSettings.analyzeFilesPath,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.analyzeFilesPath =
                              _tmpTextController?.text ?? "";
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
            title: const Text("Servidor IMAP"),
            textColor: (GlobalSettings.imapServer.isNotEmpty)
                ? null
                : Colors.red,
            subtitle: const Text("Define o servidor IMAP para conexão"),
            onTap: () {
              // Ação ao tocar na opção de servidor IMAP
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar Servidor IMAP"),
                    content: TextField(
                      decoration: const InputDecoration(
                        hintText: "Digite o endereço do servidor IMAP",
                      ),
                      controller: _tmpTextController = TextEditingController(
                        text: GlobalSettings.imapServer,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.imapServer =
                              _tmpTextController?.text ??
                              ""; // Garante atribuição não-nula
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
            textColor:
                ((GlobalSettings.imapPort > 0 &&
                    GlobalSettings.imapPort < 65536))
                ? null
                : Colors.red,
            subtitle: const Text(
              "Define a porta IMAP do servidor para conexão",
            ),
            onTap: () {
              // Ação ao tocar na opção de porta IMAP
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Configurar porta IMAP"),
                    content: TextField(
                      decoration: const InputDecoration(
                        hintText: "Digite a porta IMAP",
                      ),
                      controller: _tmpTextController = TextEditingController(
                        text: GlobalSettings.imapPort.toString(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          GlobalSettings.imapPort =
                              _tmpTextController!.text.isNotEmpty
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
                      decoration: const InputDecoration(
                        hintText: "Digite seu email",
                      ),
                      controller: _tmpTextController = TextEditingController(
                        text: GlobalSettings.mail,
                      ),
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
                      decoration: const InputDecoration(
                        hintText: "Digite sua senha",
                      ),
                      controller: _tmpTextController = TextEditingController(
                        text: GlobalSettings.password,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() {
                          // Atualiza o estado para refletir a nova senha
                          GlobalSettings.password =
                              _tmpTextController?.text ?? "";
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
        ],
      ),
    );
  }
}

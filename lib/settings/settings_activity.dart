import 'package:flutter/material.dart';
import 'package:myapp/settings/global.dart';

class SettingsActivity extends StatelessWidget {
  const SettingsActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingActivityHome();
  }
}

class SettingActivityHome extends StatefulWidget {
  const SettingActivityHome({super.key});

  @override
  State<SettingActivityHome> createState() => _SettingActivityState();
}

class _SettingActivityState extends State<SettingActivityHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configurações")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Diretório dos arquivos locais"),
            textColor: GlobalSettings.analyzeFilesPath?.isNotEmpty ?? true
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
                      controller: TextEditingController(
                        text: GlobalSettings.analyzeFilesPath ?? "",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          GlobalSettings.analyzeFilesPath =
                              TextEditingController().text;
                          Navigator.of(context).pop();
                        },
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
            textColor: (GlobalSettings.imapServer?.isNotEmpty ?? false)
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
                      controller: TextEditingController(
                        text: GlobalSettings.imapServer ?? "",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          GlobalSettings.imapServer =
                              TextEditingController().text;
                          Navigator.of(context).pop();
                        },
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
            textColor: GlobalSettings.mail?.isNotEmpty ?? false
                ? null
                : Colors.red,
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
                      controller: TextEditingController(
                        text: GlobalSettings.mail ?? "",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          GlobalSettings.mail = TextEditingController().text;
                          Navigator.of(context).pop();
                        },
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
            textColor: GlobalSettings.password?.isNotEmpty ?? false
                ? null
                : Colors.red,
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
                      controller: TextEditingController(
                        text: GlobalSettings.password ?? "",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          GlobalSettings.password =
                              TextEditingController().text;
                          Navigator.of(context).pop();
                        },
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

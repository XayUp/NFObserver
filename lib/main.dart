import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myapp/service/mail/mail_service.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/widgets/list/file_item.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necessário para usar await antes do runApp
  await GlobalSettings.init(); // <- Aqui você inicializa sua classe

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _sysncInfo;
  TextEditingController? _searchTextController;

  List<String> listDocs = [];

  ImapClient? imapClient;

  Future<void> lerEmails() async {
    final client = ImapClient(isLogEnabled: true);
    List<String>? tmpMessages;
    try {
      await client.connectToServer(
        GlobalSettings.imapServer!,
        GlobalSettings.imapPort,
        isSecure: true,
      );
      await client.login(GlobalSettings.mail!, GlobalSettings.password!);
      // Listar as caixas de e-mail
      var mailBoxes = await client.listMailboxes(
        mailboxPatterns: ["*"],
        recursive: true,
      );
      // Suggested code may be subject to a license. Learn more: ~LicenseLog:1963415062.
      Mailbox? mailBox;
      for (var tmpMailBox in mailBoxes) {
        //if (kDebugMode) {
        debugPrint("On loop ${tmpMailBox.name}");
        debugPrint(tmpMailBox.encodedPath);
        debugPrint(
          "Is SEND?: ${tmpMailBox.encodedPath.toUpperCase().contains(RegExp("SENT|ENVIADAS"))}",
        );
        //}
        if (tmpMailBox.encodedPath.toUpperCase().contains(
          RegExp("SENT|ENVIADAS"),
        )) {
          mailBox = tmpMailBox;
          break;
        }
      }

      //mailBox = null;

      if (mailBox != null) {
        await client.selectMailbox(mailBox);
        listDocs.add("MailBox: ${mailBox.name}");
      } else {
        listDocs.add("MailBox: ${(await client.selectInbox()).name}");
      }

      // fetch 10 most recent messages:
      final fetchResult = await client.fetchRecentMessages(
        messageCount: 10,
        criteria: 'BODY.PEEK[TEXT]',
      );

      tmpMessages = [];

      for (final message in fetchResult.messages) {
        String? text = printMessage(message);
        if (text != null) {
          tmpMessages.add("###### INÍCIO ######\n$text\n######   FIM  ######");
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoading = true;
        _sentStatus.clear();
        final files = targetDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();
        files.sort(
          (a, b) => path
              .basename(a.path)
              .toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase()),
        );
        filesList = files;
      });
      await _checkFilesSentStatus();
    }
  }

  Future<void> _checkFilesSentStatus() async {
    try {
      final sentAttachmentNames = await _mailService
          .fetchAllSentAttachmentNames();

      final newStatus = <String, bool>{};
      for (final file in filesList) {
        newStatus[file.path] = sentAttachmentNames.contains(
          path.basename(file.path).toLowerCase(),
        );
      }

      setState(() {
        _sentStatus = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao sincronizar: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void syncronizeFiles() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: _isLoading
            ? const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(width: 16),
                ],
              )
            : Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: filesList.length,
              itemBuilder: (context, index) {
                final file = filesList[index];
                final isSent = _sentStatus[file.path] ?? false;
                return FileItem(
                  file: file,
                  isSent: isSent,
                  subtitleFilter: (file) {
                    final fileName = path.basename(file.path);
                    final relativePath = path
                        .dirname(file.path)
                        .replaceFirst(GlobalSettings.analyzeFilesPath, "");
                    var finalSubtitle = fileName.contains(RegExp('NF \\d*'))
                        ? "Possível Nota Fiscal"
                        : RegExp(
                            r'^((\d{2}|\d{2}-\d{2})\.\d{2}\.\d{2})',
                          ).hasMatch(fileName)
                        ? "Possível anotação/relatório"
                        : "";
                    if (finalSubtitle.isNotEmpty) finalSubtitle += "\n";
                    finalSubtitle += 'Diretório: $relativePath';
                    return finalSubtitle;
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isLoading ? null : _updateLocalFiles,
            child: Icon(Icons.refresh),
          ),
          FloatingActionButton(
            onPressed: () => syncronizeFiles(),
            mini: true,
            child: Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

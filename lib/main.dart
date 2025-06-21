import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/settings/settings_activity.dart';

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

  String emailLogin = "";
  String senhaLogin = "";

  String imapServer = "";
  int imapPort = 0;

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
        if (tmpMessages == null) {
          listDocs.clear();
        } else {
          listDocs = tmpMessages;
        }
      });
      if (client.isConnected) client.logout();
    }
  }

  String? printMessage(MimeMessage message) {
    String text = "";
    //'\nfrom: ${message.from} with subject "${message.decodeSubject()}"';
    /*if (!message.isTextPlainMessage()) {
      text += '\ncontent-type: ${message.mediaType}';
      //text += 'Message: ${message.decodeContentText()}';
    } else {
      final plainText = message.decodeTextPlainPart();
      if (plainText != null) {
        final lines = plainText.split('\r\n');
        for (final line in lines) {
          if (line.startsWith('>')) {
            // break when quoted text starts
            break;
          }
          text += "\n$line";
        }
      }
    }*/
    final parts = message.allPartsFlat;

    final attachments = parts.where((part) => part.decodeFileName() != null);

    if (attachments.isNotEmpty) {
      text += "\n📎 Anexos:";
      for (final attachment in attachments) {
        final filename = attachment.decodeFileName() ?? "sem_nome.ext";
        text += "\n - $filename";
      }
      return text;
    }
    return null;
  }

  void searchMessage(String text) {}

  void _loadList() {
    listDocs.clear();
    lerEmails();
  }

  bool _checkEssentialMailSettings() {
    if (SettingsActivity.getEssentialMailSettings().isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Há algumas configurações a serem feitas"),
            content: Text(
              SettingsActivity.getEssentialMailSettings().join("\n"),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsActivity(),
                    ),
                  );
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEssentialMailSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_sysncInfo ?? "ASFASF"),
          ),
          ListView.builder(
            itemCount: listDocs.length,
            itemBuilder: (context, index) {
              return ListTile(title: Text(listDocs[index]), dense: true);
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_checkEssentialMailSettings()) {
            _loadList();
          }
        },
        tooltip: 'Sicronizar',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                "NF Oserver",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsActivity(),
                  ),
                );
              },
              child: Text(
                'Configurações',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

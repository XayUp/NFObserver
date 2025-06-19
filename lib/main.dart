import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';

void main() {
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
  List<String> listDocs = [];

  String emailLogin = "";
  String senhaLogin = "";

  String imapServer = "";
  int imapPort = 0;

  ImapClient? imapClient;

  Future<void> lerEmails() async {
    final client = ImapClient(isLogEnabled: true);
    await client.connectToServer(imapServer, imapPort, isSecure: true);
    await client.login(emailLogin, senhaLogin);
    // Listar as caixas de e-mail
    var mailBoxes = await client.listMailboxes(
      mailboxPatterns: ["*"],
      recursive: true,
    );
    // Suggested code may be subject to a license. Learn more: ~LicenseLog:1963415062.
    Mailbox? mailBox;
    for (var tmpMailBox in mailBoxes) {
      //if (kDebugMode) {
      print("On loop ${tmpMailBox.name}");
      print(tmpMailBox.encodedPath);
      print(
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

    if (mailBox != null) {
      await client.selectMailbox(mailBox);
      listDocs.add("MailBox: ${mailBox.name}");
    } else {
      listDocs.add("MailBox: ${(await client.selectInbox()).name}");
    }

    // fetch 10 most recent messages:
    final fetchResult = await client.fetchRecentMessages(
      messageCount: 10,
      criteria: 'BODY.PEEK[]',
    );

    final searchText = MailSearchResult.empty(
      MailSearch('pagamento', SearchQueryType.body),
    );

    //searchText.addMessage(fetchResult.messages[0]);

    //client.searchMessages();

    for (final message in fetchResult.messages) {
      printMessage(message);
    }

    setState(() {});

    await client.logout();
  }

  void printMessage(MimeMessage message) {
    //setState(() {
    String text =
        '\nfrom: ${message.from} with subject "${message.decodeSubject()}"';
    if (!message.isTextPlainMessage()) {
      text += '\ncontent-type: ${message.mediaType}';
      text += 'Message: ${message.decodeContentText()}';
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
    }
    listDocs.add(text);
    //});
  }

  void searchMessage(String text) {}

  void _loadList() {
    listDocs.clear();
    lerEmails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView.builder(
          itemCount: listDocs.length,
          itemBuilder: (context, index) {
            return ListTile(title: Text(listDocs[index]));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadList,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

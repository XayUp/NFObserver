import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/settings/global.dart';

class MailService {
  final bool _isLogEnabled;

  MailService({bool isLogEnabled = kDebugMode}) : _isLogEnabled = isLogEnabled;

  Future<T> _withConnection<T>(
    Future<T> Function(ImapClient client) action,
  ) async {
    final client = ImapClient(isLogEnabled: _isLogEnabled);
    try {
      final mail = GlobalSettings.mail;
      final password = GlobalSettings.password;
      final server = GlobalSettings.imapServer;
      final port = GlobalSettings.imapPort;

      if (server.isEmpty || mail.isEmpty || password.isEmpty) {
        throw Exception(
          "Configurações de IMAP (servidor, email ou senha) não foram definidas.",
        );
      }

      await client.connectToServer(server, port, isSecure: true);
      await client.login(mail, password);
      return await action(client);
    } catch (e) {
      debugPrint("Ocorreu um erro ao tentar se conectar: $e");
      rethrow;
    } finally {
      if (client.isConnected) {
        await client.logout();
      }
    }
  }

  /// Busca os nomes de todos os anexos em todas as pastas de "Enviados".
  ///
  /// Usa `BODYSTRUCTURE` para obter os nomes dos arquivos sem baixar seu conteúdo,
  /// tornando a operação extremamente rápida e eficiente em termos de dados.
  /// Retorna um `Set` para buscas de alta performance.
  Future<Set<String>> fetchAllSentAttachmentNames() async {
    return await _withConnection((client) async {
      final allMailboxes = await client.listMailboxes(
        mailboxPatterns: ["*"],
        recursive: true,
      );

      final sentMailboxes = allMailboxes.where((mailbox) {
        final upperCaseName = mailbox.path.toUpperCase();
        return mailbox.isSent ||
            upperCaseName.contains("SENT") ||
            upperCaseName.contains("ENVIADOS") ||
            upperCaseName.contains("ENVIADAS");
      }).toList();

      if (sentMailboxes.isEmpty) return <String>{};

      final allAttachmentNames = <String>{};
      for (final mailbox in sentMailboxes) {
        await client.selectMailbox(mailbox);
        if (mailbox.messagesExists < 1) continue;

        final fetchResult = await client.fetchMessagesByCriteria(
          '1:* (BODYSTRUCTURE)',
        );

        for (final message in fetchResult.messages) {
          if (message.hasAttachments()) {
            for (final contentInfo in message.findContentInfo(
              disposition: ContentDisposition.attachment,
            )) {
              if (contentInfo.fileName != null) {
                allAttachmentNames.add(contentInfo.fileName!.toLowerCase());
              }
            }
          }
        }
      }
      return allAttachmentNames;
    });
  }
}

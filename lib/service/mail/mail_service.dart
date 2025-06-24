import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/settings/settings_activity.dart';

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
          "As seguintes configurações ainda não foram definidas: ${SettingsActivity.getEssentialMailSettings().join("\n")}",
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
      List<Mailbox> allMailboxes = await client.listMailboxes(
        mailboxPatterns: ["*"],
        recursive: true,
      );
      //Todos os MailBox do tipo "ENVIADAS" permanecerão na lista
      allMailboxes = allMailboxes.where((mailBox) {
        return mailBox.isSent ||
            mailBox.encodedPath.toUpperCase().contains(RegExp("SENT|ENVIADAS"));
      }).toList();

      if (allMailboxes.isEmpty) return <String>{};

      final allAttachmentNames = <String>{};
      for (final mailBox in allMailboxes) {
        await client.selectMailbox(mailBox);
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
      debugPrint(allAttachmentNames.toString());
      return allAttachmentNames;
    });
  }

  Future<MimeMessage> fetchFullMessage(
    int messageId,
    String mailBoxPath,
  ) async {
    return await _withConnection((client) async {
      await client.selectMailboxByPath(mailBoxPath);
      final message = await client.fetchMessage(messageId, 'BODY.PEEK[]');
      //Retorna a única MimeMessage solicitada
      return message.messages.first;
    });
  }
}

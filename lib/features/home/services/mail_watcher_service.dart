import 'dart:async';
import 'package:flutter/foundation.dart';

/// Interface para ouvir eventos do "Vigia de Email".
abstract class MailWatcherListener {
  /// Chamado quando o vigia detecta um novo email.
  /// Para uma implementação real, você pode querer passar mais detalhes,
  /// como os nomes dos anexos do novo e-mail.
  void onNewMailDetected();

  /// Chamado se ocorrer um erro durante a monitorização.
  void onMailWatcherError(Object error);
}

/// Um serviço para "observar" uma caixa de entrada de e-mail por novas mensagens.
///
/// **NOTA:** Esta é uma implementação **simulada** usando um Timer para fins
/// de demonstração. Ela mostra *como* integrar um vigia de e-mail no seu app.
/// Para uma implementação real, você substituiria o Timer pela lógica do comando
/// IMAP IDLE, usando uma biblioteca como `enough_mail`.
class MailWatcherService {
  MailWatcherService._();

  static Timer? _simulationTimer;
  static MailWatcherListener? _listener;

  /// Inicia a monitorização da caixa de entrada.
  static void startWatching(MailWatcherListener listener) {
    stopWatching(); // Garante que não haja múltiplos vigias rodando.
    _listener = listener;
    debugPrint("Vigia de Email INICIADO (Modo de Simulação).");

    // SIMULAÇÃO: A cada 30 segundos, finge que um novo e-mail chegou.
    _simulationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      debugPrint("Vigia de Email: Novo e-mail detectado (simulação)!");
      _listener?.onNewMailDetected();
    });
  }

  /// Para a monitorização.
  static void stopWatching() {
    if (_simulationTimer != null) {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      _listener = null;
      debugPrint("Vigia de Email PARADO.");
    }
  }
}

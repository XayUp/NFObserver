import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

abstract class DirectoryWatcherListener {
  /// Chamado quando um novo arquivo ou diretório é criado.
  void onCreated(FileSystemCreateEvent entity) {
    debugPrint('onCreated: ${entity.path}');
  }

  /// Chamado quando o conteúdo de um arquivo é modificado.
  void onModified(FileSystemModifyEvent entity) {
    debugPrint('onModified: ${entity.path}');
  }

  /// Chamado quando um arquivo ou diretório é removido.
  void onDeleted(FileSystemDeleteEvent entity) {
    debugPrint('onDeleted: ${entity.path}');
  }

  /// Chamado quando um arquivo ou diretório é movido ou renomeado.
  void onMoved(FileSystemMoveEvent event) {
    debugPrint('onMoved: ${event.path} -> ${event.destination}');
  }

  /// Chamado se ocorrer um erro durante a monitorização.
  void onError(Object error) {
    debugPrint('onError: $error');
  }
}

class DirectoryWatcherService {
  DirectoryWatcherService._(); // Construtor privado

  static StreamSubscription<FileSystemEvent>? _subscription;
  static String? _watchedPath;

  /// Inicia a monitorização de um diretório.
  /// Se um diretório já estiver sendo monitorado, a monitorização anterior é parada.
  ///
  /// [path]: O caminho do diretório a ser monitorado.
  /// [listener]: A instância que irá receber as notificações de eventos.

  static void startWatching(String path, DirectoryWatcherListener listener) {
    stopWatching(); // Para qualquer monitoramento anterior

    final directory = Directory(path);
    if (!directory.existsSync()) {
      listener.onError(Exception('Directory does not exist: $path'));
      return;
    }

    _watchedPath = path;

    _subscription = directory.watch(recursive: true).listen(
      (event) {
        // Delega o evento para o método apropriado no listener
        if (event is FileSystemCreateEvent) listener.onCreated(event);
        if (event is FileSystemModifyEvent) listener.onModified(event);
        if (event is FileSystemDeleteEvent) listener.onDeleted(event);
        if (event is FileSystemMoveEvent) listener.onMoved(event);
      },
      onError: (e) => listener.onError(e),
    );
    debugPrint('Started watching directory: $path');
  }

  /// Para a monitorização do diretório atual.
  static void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
    _watchedPath = null;
    debugPrint('Stopped watching directory.');
  }

  /// Retorna o caminho do diretório que está sendo monitorado atualmente.
  static String? get watchedPath => _watchedPath;

  static void dispose() {
    stopWatching();
    debugPrint('DirectoryWatcherService disposed.');
  }
}

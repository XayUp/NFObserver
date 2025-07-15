import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nfobserver/features/home/services/mail_watcher_service.dart';
import 'package:nfobserver/features/home/services/directory_watcher_service.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/features/settings/view/settings_activity.dart';
import 'package:nfobserver/models/consolidated_nf.dart';
import 'package:nfobserver/models/nf_doc/nf_doc.dart';
import 'package:nfobserver/models/xml/nf_xml.dart';
import 'package:nfobserver/service/mail/mail_service.dart';
import 'package:nfobserver/utils/file_type_identifier.dart';
import 'package:nfobserver/utils/doc_name_parser.dart';
import 'package:path/path.dart' as p;

/// Implementação do listener para reagir a eventos do diretório de NFs.
class _NFDirectoryListener extends DirectoryWatcherListener {
  final NFProvider _provider;
  _NFDirectoryListener(this._provider);

  @override
  void onCreated(FileSystemCreateEvent entity) {
    if (entity is File) {
      debugPrint("Watcher: Novo arquivo detectado - ${entity.path}");
      // TODO: Implementar lógica para adicionar o novo arquivo à lista de forma eficiente,
      // sem recarregar tudo.
      _provider.loadAndConsolidateData(); // Solução simples por enquanto
    }
  }

  @override
  void onDeleted(FileSystemDeleteEvent entity) {
    debugPrint("Watcher: Arquivo removido - ${entity.path}");
    // TODO: Implementar lógica para remover o arquivo da lista.
    _provider.loadAndConsolidateData(); // Solução simples por enquanto
  }

  @override
  void onMoved(FileSystemMoveEvent event) {
    _provider.handleFileMove(event);
  }

  @override
  void onError(Object error) {
    debugPrint("Watcher Error: $error");
    _provider._updateStatus("Erro no monitoramento de diretório: $error");
  }
}

/// Implementação do listener para reagir a eventos do vigia de e-mail.
class _NfMailListener extends MailWatcherListener {
  final NFProvider _provider;
  _NfMailListener(this._provider);

  @override
  void onNewMailDetected() {
    debugPrint("Listener de Email: Notificação recebida. Atualizando status de enviados...");
    // Chama o método no provider para atualizar a lista de forma eficiente.
    _provider.refreshSentStatus();
  }

  @override
  void onMailWatcherError(Object error) {
    _provider._updateStatus("Erro no Vigia de Email: $error");
  }
}

class NFProvider with ChangeNotifier {
  final MailService _mailService = MailService();
  bool _isLoading = false;
  bool _isEnriching = false;
  String _statusMessage = 'Aguardando para iniciar...';
  final List<ConsolidatedNF> _consolidatedList = [];
  FilterSortType _filterSortType = FilterSortType.nameAz;

  // Getters públicos para a UI
  bool get isLoading => _isLoading;
  bool get isEnriching => _isEnriching;
  String get statusMessage => _statusMessage;
  List<ConsolidatedNF> get consolidatedList => _consolidatedList;
  FilterSortType get filterSortType => _filterSortType;

  Future<void> handleFileMove(FileSystemEvent event) async {
    if (event is FileSystemMoveEvent) {
      final oldPath = event.path;
      final newPath = event.destination;

      if (newPath == null || p.basename(oldPath) == p.basename(newPath)) return;

      // Encontra o item correspondente ao caminho antigo.
      final index = _consolidatedList.indexWhere((nf) => nf.docData.path == oldPath);

      if (index == -1) {
        // Se não encontrou, pode ser um arquivo de uma subpasta que não estava sendo listada
        // ou um problema de sincronia. A forma mais segura é recarregar tudo.
        debugPrint("Watcher: Arquivo movido não encontrado na lista. Recarregando...");
        await loadAndConsolidateData();
        return;
      }

      debugPrint("Watcher: Atualizando arquivo renomeado: $oldPath -> $newPath");

      try {
        // Cria um novo objeto NFDoc a partir do novo caminho.
        final newFile = File(newPath);
        final newDoc = NFDoc.fromFile(newFile);
        newDoc.lastModification = newFile.lastModifiedSync().toString();

        // --- Re-enriquece os dados para este arquivo específico ---
        final docNameWithoutExtension = p.basenameWithoutExtension(newDoc.file.path);

        // 1. Extrai dados do novo nome do arquivo.
        final fileType = FileTypeIdentifier.getFileType(docNameWithoutExtension);
        final formatsForThisType = GlobalSettings.docNameFormats[fileType.name.toUpperCase()];
        Map<String, String> parsedData = {};
        if (formatsForThisType != null) {
          for (final format in formatsForThisType) {
            parsedData = DocNameParser.parse(docNameWithoutExtension, format);
            if (parsedData.isNotEmpty) break;
          }
        }
        newDoc.supplierName = parsedData['NOME_FORNECEDOR'];
        newDoc.date = parsedData['DATA'];

        /*
        // 2. Re-verifica o status de envio e os dados do XML.
        // Nota: Isso envolve I/O (rede e disco), mas garante a consistência.
        final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();
        final isSent = sentAttachmentNames.contains(p.basename(newDoc.file.path).toLowerCase());
        final nfNumberKey = parsedData['NUMERO_NF'] ?? docNameWithoutExtension.replaceAll(RegExp(r'[^0-9]'), '');
        final xmlMap = await _loadXmls(); // Idealmente, isso viria de um cache.
        final matchingXml = xmlMap[nfNumberKey];
*/

        // Substitui o item antigo pelo novo.
        _consolidatedList[index] = ConsolidatedNF(
          docData: newDoc,
          xmlData: _consolidatedList[index].xmlData, //Utiliza os dados anteriores
          isSent: _consolidatedList[index].isSent, //Utiliza os dados anteriores
          processingStatus: ProcessingStatus.complete,
        );

        // Reordena a lista com o critério atual e notifica a UI.
        sortList(_filterSortType);
      } catch (e) {
        debugPrint("Watcher: Erro ao atualizar arquivo renomeado: $e. Recarregando...");
        await loadAndConsolidateData();
      }
    }
  }

  /// Orquestra o carregamento dos documentos, a verificação de status (enviado/não enviado)
  /// e o cruzamento de dados com os arquivos XML.
  Future<void> loadAndConsolidateData() async {
    if (_isLoading || _isEnriching) return; // Previne execuções múltiplas
    _startWatchers();
    try {
      _isLoading = true;
      _statusMessage = 'Lendo diretório de documentos...';
      _consolidatedList.clear();
      notifyListeners();

      // --- PASSO 1: Carregamento Rápido em Primeiro Plano ---
      final directoryPath = GlobalSettings.analyzeFilesPath;
      if (directoryPath.isEmpty) {
        _statusMessage = "Erro: O diretório de análise de arquivos não foi configurado.";
        _isLoading = false;
        _isEnriching = false;
        notifyListeners();
        return; // Encerra a execução do método
      }
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        _statusMessage = "Erro: O diretório '$directoryPath' não foi encontrado.";
        _isLoading = false;
        _isEnriching = false;
        notifyListeners();
        return; // Encerra a execução do método
      }

      final files = directory.listSync(recursive: true).whereType<File>().toList();
      if (files.isEmpty) {
        _updateStatus('Nenhum documento encontrado no diretório.');
        _isLoading = false;
        _isEnriching = false;
        notifyListeners();
        return;
      }

      // Popula a lista com os dados iniciais (apenas o documento)
      for (final file in files) {
        final doc = NFDoc.fromFile(file);
        doc.lastModification = file.lastModifiedSync().toString();
        _consolidatedList.add(ConsolidatedNF(docData: doc, isSent: false, processingStatus: ProcessingStatus.pending));
      }

      // Ordena a lista e notifica a UI para exibir a lista inicial imediatamente.
      sortList(_filterSortType);
      _isLoading = false; // O carregamento inicial terminou
      _enrichData();
    } catch (e) {
      _statusMessage = "Erro ao carregar: ${e.toString().replaceFirst("Exception: ", '')}";
      _isLoading = false;
      _isEnriching = false; // Garante que a flag seja resetada em caso de erro
      notifyListeners();
    }
  }

  /// Inicia o processo de enriquecimento de dados em etapas.
  Future<void> _enrichData() async {
    if (_isEnriching) return;
    try {
      _isEnriching = true;

      // Etapa 1: Verificar status de envio.
      await _enrichWithSentStatus();

      // Etapa 2: Processar nomes e cruzar com XMLs.
      await _enrichWithXmlAndNameParsing();

      // Etapa Final: Marcar todos como completos e finalizar.
      for (int i = 0; i < _consolidatedList.length; i++) {
        _consolidatedList[i] = _consolidatedList[i].copyWith(processingStatus: ProcessingStatus.complete);
      }

      _updateStatus('Processo finalizado. ${_consolidatedList.length} documentos verificados.');
    } catch (e) {
      _statusMessage = "Erro durante o enriquecimento: ${e.toString().replaceFirst("Exception: ", '')}";
      notifyListeners();
    } finally {
      _isEnriching = false;
      // A notificação final é feita para garantir que a UI remova o indicador de progresso.
      notifyListeners();
    }
  }

  /// Etapa do enriquecimento: Processa nomes dos arquivos e cruza com XMLs.
  Future<void> _enrichWithXmlAndNameParsing() async {
    _updateStatus("Analisando nomes de arquivos e cruzando com XMLs...");
    final xmlMap = await _loadXmls();

    for (int i = 0; i < _consolidatedList.length; i++) {
      final currentNf = _consolidatedList[i];
      final doc = currentNf.docData;

      final docNameWithoutExtension = p.basenameWithoutExtension(doc.file.path);
      final fileType = FileTypeIdentifier.getFileType(docNameWithoutExtension);
      final formatsForThisType = GlobalSettings.docNameFormats[fileType.name.toUpperCase()];

      Map<String, String> parsedData = {};
      if (formatsForThisType != null) {
        for (final format in formatsForThisType) {
          parsedData = DocNameParser.parse(docNameWithoutExtension, format);
          if (parsedData.isNotEmpty) break;
        }
      }

      doc.supplierName = parsedData['NOME_FORNECEDOR'];
      doc.date = parsedData['DATA'];

      final nfNumberKey = parsedData['NUMERO_NF'] ?? docNameWithoutExtension.replaceAll(RegExp(r'[^0-9]'), '');
      final matchingXml = xmlMap[nfNumberKey];

      _consolidatedList[i] = currentNf.copyWith(docData: doc, xmlData: matchingXml);

      // Notifica a UI após processar cada arquivo
      notifyListeners();
    }
    _updateStatus("Nomes e XMLs processados. Atualizando lista...");
  }

  /// Etapa do enriquecimento: Verifica o status de envio dos documentos.
  Future<void> _enrichWithSentStatus() async {
    _updateStatus("Verificando status de envio dos documentos...");
    final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();

    for (int i = 0; i < _consolidatedList.length; i++) {
      final currentNf = _consolidatedList[i];
      final isSent = sentAttachmentNames.contains(p.basename(currentNf.docData.file.path).toLowerCase());
      _consolidatedList[i] = currentNf.copyWith(isSent: isSent);

      // Notifica a UI após verificar o status de cada arquivo
      notifyListeners();
    }
    _updateStatus("Status de envio verificado. Atualizando lista...");
  }

  /// Atualiza o status de 'enviado' de todos os documentos na lista.
  /// É chamado pelo vigia de e-mail e é mais eficiente do que recarregar tudo.
  Future<void> refreshSentStatus() async {
    try {
      _updateStatus("Vigia de Email: Verificando novos e-mails enviados...");
      final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();

      bool hasChanges = false;
      for (int i = 0; i < _consolidatedList.length; i++) {
        final currentNf = _consolidatedList[i];
        final newSentStatus = sentAttachmentNames.contains(p.basename(currentNf.docData.file.path).toLowerCase());

        if (currentNf.isSent != newSentStatus) {
          _consolidatedList[i] = currentNf.copyWith(isSent: newSentStatus);
          hasChanges = true;
        }
      }

      if (hasChanges) {
        _updateStatus("Status de envio atualizado para um ou mais arquivos.");
        notifyListeners();
      }
    } catch (e) {
      _updateStatus("Erro ao atualizar status de envio: $e");
    }
  }

  Future<Map<String, NFXML>> _loadXmls() async {
    _updateStatus("Lendo o diretório dos XMLs...");
    final Map<String, NFXML> xmls = {};
    final directoryPath = GlobalSettings.xmlPath;
    if (directoryPath.isEmpty) return xmls;

    final directory = Directory(directoryPath);
    if (!await directory.exists()) return xmls;

    final files = directory.listSync().whereType<File>().where(
      (file) => p.extension(file.path).toLowerCase() == '.xml',
    );

    for (final file in files) {
      final nfXml = await NFXML.fromFile(file);
      if (nfXml != null) {
        xmls[nfXml.nfNumber.toString()] = nfXml;
      }
    }
    return xmls;
  }

  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  void _startWatchers() {
    DirectoryWatcherService.startWatching(
      GlobalSettings.analyzeFilesPath,
      _NFDirectoryListener(this),
    );
    MailWatcherService.startWatching(
      _NfMailListener(this),
    );
    debugPrint("Vigias de diretório e email iniciados.");
  }

  /// Permite que o usário possa escolher a ordem de exibição dos documentos.
  /// Todos os modos suportados estão em [FileSortType]
  void sortList(FilterSortType sortMode) {
    _filterSortType = sortMode;
    if (_filterSortType == FilterSortType.nameAz) {
      _consolidatedList.sort((a, b) => a.docData.name!.toLowerCase().compareTo(b.docData.name!.toLowerCase()));
    } else if (_filterSortType == FilterSortType.nameZa) {
      _consolidatedList.sort((a, b) => b.docData.name!.toLowerCase().compareTo(a.docData.name!.toLowerCase()));
    } else if (_filterSortType == FilterSortType.dateAsc) {
      _consolidatedList.sort((a, b) => a.docData.lastModification!.compareTo(b.docData.lastModification!));
    } else if (_filterSortType == FilterSortType.dateDesc) {
      _consolidatedList.sort((a, b) => b.docData.lastModification!.compareTo(a.docData.lastModification!));
    }
    notifyListeners();
  }
}

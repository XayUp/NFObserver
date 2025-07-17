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
  final List<NFXML> _unidentifiedXmls = [];
  FilterSortType _filterSortType = FilterSortType.dateAsc;

  // Getters públicos para a UI
  bool get isLoading => _isLoading;
  bool get isEnriching => _isEnriching;
  String get statusMessage => _statusMessage;
  List<ConsolidatedNF> get consolidatedList => _consolidatedList;
  List<NFXML> get unidentifiedXmls => _unidentifiedXmls;
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

      final oldNFDoc = _consolidatedList[index].docData;

      try {
        // Cria um novo objeto NFDoc a partir do novo caminho.
        final newFile = File(newPath);
        final newDoc = NFDoc.fromFile(newFile);
        newDoc.lastModification = newFile.lastModifiedSync().toString();

        // Substitui o item antigo pelo novo.
        _consolidatedList[index] = ConsolidatedNF(
          docData: newDoc,
          xmlData: oldNFDoc.name != newDoc.name
              ? await _fetchDocumentXML(newDoc, true)
              : _consolidatedList[index].xmlData, //Utiliza os dados anteriores
          isSent: oldNFDoc.name != newDoc.name
              ? await fetchDocumentSentStatus(newDoc)
              : _consolidatedList[index].isSent, //Utiliza os dados anteriores
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
        final nfDoc = NFDoc.fromFile(file);
        nfDoc.lastModification = file.lastModifiedSync().toString();
        _consolidatedList.add(
          ConsolidatedNF(docData: nfDoc, isSent: false, processingStatus: ProcessingStatus.pending),
        );
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

    await fetchAllDocumentsXML(true);
    //notifyListeners();
    _updateStatus("Nomes e XMLs processados. Atualizando lista...");
  }

  /// Carrega os XML no diretório definido nas configurações
  /// O resultado é retorna mas também é guardado na variável [unindetifedXmls]
  Future<List<NFXML>> _loadXmls() async {
    _updateStatus("Lendo o diretório dos XMLs...");
    _unidentifiedXmls.clear();
    final directoryPath = GlobalSettings.xmlPath;
    if (directoryPath.isEmpty) return _unidentifiedXmls;

    final directory = Directory(directoryPath);
    if (!await directory.exists()) return _unidentifiedXmls;

    final files = directory.listSync().whereType<File>().where(
      (file) => p.extension(file.path).toLowerCase() == '.xml',
    );

    for (final file in files) {
      final nfXml = await NFXML.fromFile(file);
      if (nfXml != null) {
        _unidentifiedXmls.add(nfXml);
        //_updateStatus("XML Indentificado: ${nfXml.nfKey}");
      }
    }
    return _unidentifiedXmls;
  }

  Future<void> fetchAllDocumentsXML([bool force = false]) async {
    final xmls = force ? await _loadXmls() : unidentifiedXmls;
    if (xmls.isEmpty) return;

    for (int cI = 0; cI < _consolidatedList.length; cI++) {
      final nfDoc = consolidatedList[cI];
      for (NFXML xml in xmls) {
        if (_compareXmlWithDoc(nfDoc.docData, xml)) {
          consolidatedList[cI] = nfDoc.copyWith(xmlData: xml);
          xmls.remove(xml);
          notifyListeners();
          break;
        }
      }
    }
  }

  /// Tente buscar o XML correspondente ao documento.
  /// Este processo compara o nome do fornecedor e o número da nota obtidos pelo Parser
  /// Caso as duas ocorrência existam, o XML é encontrado
  /// A variável [force] faz com que a lista [unidentifiedXmls] seja recarregada, mesmo se não estiver vazia.
  /// Retorna nulo caso nenhum XML corresponde ao documento
  /// Caso contrário, o [NFXML] é retornado
  Future<NFXML?> _fetchDocumentXML(NFDoc nfDoc, [bool force = false]) async {
    final xmls = force ? await _loadXmls() : unidentifiedXmls;
    if (xmls.isEmpty) return null;

    for (NFXML xml in xmls) {
      if (_compareXmlWithDoc(nfDoc, xml)) {
        return xml;
      }
    }

    return null;
  }

  ///Retorna [true] se nfDoc e nfXml se cruzam
  bool _compareXmlWithDoc(NFDoc nfDoc, NFXML nfXml) {
    final docNameWithoutExtension = p.basenameWithoutExtension(nfDoc.file.path);
    final fileType = FileTypeIdentifier.getFileType(docNameWithoutExtension);
    final formatsForThisType = GlobalSettings.docNameFormats[fileType.name.toUpperCase()];

    Map<String, String> parsedData = {};
    if (formatsForThisType != null) {
      for (final format in formatsForThisType) {
        parsedData = DocNameParser.parse(docNameWithoutExtension, format);
        if (parsedData.isNotEmpty) break;
      }
    }

    nfDoc.supplierName = parsedData['NOME_FORNECEDOR'];
    final nfNumberKey = parsedData['NUMERO_NF'] ?? docNameWithoutExtension.replaceAll(RegExp(r'[^0-9]'), '');

    debugPrint("Suplier: \"${nfDoc.supplierName}\" - NF: \"$nfNumberKey\"");
    debugPrint("NFXML: Fant > ${nfXml.emitFant}, Name > ${nfXml.emitName}");

    if (nfDoc.supplierName != null) {
      List<String> suplierNameSplited = nfDoc.supplierName!.split(RegExp('\\s'));
      debugPrint("Splited Suplier: $suplierNameSplited");
      if (suplierNameSplited.isNotEmpty) {
        return suplierNameSplited.firstWhere(
          (part) {
            debugPrint("Part: $part");
            return (nfXml.emitName.contains(part) || nfXml.emitFant.contains(part)) &&
                nfNumberKey == '${nfXml.nfNumber}';
          },
          orElse: () => '',
        ).isNotEmpty;
      }
    }
    return false;
  }

  Future<bool> fetchDocumentSentStatus(NFDoc nfDoc) async {
    _updateStatus("Verificando status de envio do documento ${nfDoc.name}...");
    final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();
    return sentAttachmentNames.contains(p.basename(nfDoc.file.path).toLowerCase());
  }

  //)
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

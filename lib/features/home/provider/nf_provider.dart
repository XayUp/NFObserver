import 'dart:io';

import 'package:flutter/foundation.dart';
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
class _NFDirectoryEvents extends DirectoryWatcherEvents {
  final NFProvider _provider;
  _NFDirectoryEvents(this._provider);

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
    _provider.handleFileChanged(event);
  }

  @override
  void onError(Object error) {
    debugPrint("Watcher Error: $error");
    _provider._updateStatus("Erro no monitoramento de diretório: $error");
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

  Future<void> handleFileChanged(FileSystemEvent event) async {
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
    DirectoryWatcherService.startWatching(
      GlobalSettings.analyzeFilesPath,
      _NFDirectoryEvents(this),
    );
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
      _isEnriching = true; // O enriquecimento em segundo plano começa
      _updateStatus('Verificando status dos documentos...');

      // --- PASSO 2: Enriquecimento de Dados em Segundo Plano ---
      final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();
      final xmlMap = await _loadXmls();

      // Itera pela lista existente e atualiza cada item com os dados enriquecidos.
      for (int i = 0; i < _consolidatedList.length; i++) {
        final currentNf = _consolidatedList[i];
        final doc = currentNf.docData;

        _updateStatus('Processando ${i + 1}/${_consolidatedList.length}: ${doc.name ?? ""}');

        final docNameWithoutExtension = p.basenameWithoutExtension(doc.file.path);

        // 1. Identify the file type to find the correct parsing rule.
        final fileType = FileTypeIdentifier.getFileType(docNameWithoutExtension);

        // 2. Get the list of possible formats for this file type.
        final formatsForThisType = GlobalSettings.docNameFormats[fileType.name.toUpperCase()];

        // 3. Try each format until one succeeds.
        Map<String, String> parsedData = {};
        if (formatsForThisType != null) {
          for (final format in formatsForThisType) {
            parsedData = DocNameParser.parse(docNameWithoutExtension, format);
            if (parsedData.isNotEmpty) {
              break; // Found a matching format, stop trying.
            }
          }
        }

        // Popula o objeto NFDoc com os dados extraídos do nome do arquivo.
        doc.supplierName = parsedData['NOME_FORNECEDOR'];
        doc.date = parsedData['DATA'];

        // Usa o número da NF extraído como chave para o cruzamento.
        // Se não encontrar, usa uma extração simples de números como fallback.
        final nfNumberKey = parsedData['NUMERO_NF'] ?? docNameWithoutExtension.replaceAll(RegExp(r'[^0-9]'), '');
        final matchingXml = xmlMap[nfNumberKey];
        final isSent = sentAttachmentNames.contains(p.basename(doc.file.path).toLowerCase());

        // Substitui o item na lista com uma nova instância contendo os dados completos.
        _consolidatedList[i] = ConsolidatedNF(
          docData: doc,
          xmlData: matchingXml,
          isSent: isSent,
          processingStatus: ProcessingStatus.complete,
        );

        // Notifica a UI a cada item processado para uma atualização visual incremental.
        notifyListeners();
        // Uma pequena pausa para não sobrecarregar a thread da UI.
        await Future.delayed(const Duration(milliseconds: 5));
      }

      _updateStatus('Processo finalizado. ${_consolidatedList.length} documentos verificados.');
    } catch (e) {
      _statusMessage = "Erro: ${e.toString().replaceFirst("Exception: ", '')}";
    } finally {
      _isLoading = false;
      _isEnriching = false;
      notifyListeners();
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

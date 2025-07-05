import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nfobserver/features/app_routers.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/features/settings/view/settings_activity.dart';
import 'package:nfobserver/service/mail/mail_service.dart';
import 'package:nfobserver/utils/filter_parser.dart';
import 'package:nfobserver/widgets/list/file_item.dart';
import 'package:path/path.dart' as path;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final _appTitle = "NF Observer";

  //Tipos de arquivos
  final _tagPossibleFiscalNoteType = "Possível Nota Fiscal";
  final _tagPossibleReportType = "Possível Rolatório/Anotação";
  final _tagPossibleBonus = "Possível Bonificação";
  final _tagPossiblePaid = "Possivel Nota Paga";

  //Arquivos e sincronização
  List<File> filesList = [];
  Map<String, bool> _sentStatus = {};
  bool _isLoading = false;

  final _mailService = MailService();

  //Pesquisa
  bool _isSearching = false;
  bool _hasTypedInSearch = false;
  final _searchController = TextEditingController();

  //Filtragem
  TabController? _tabController;

  //Animação do FloatingButton
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateLocalFiles();

    _fabAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    _searchController.addListener(() {
      if (mounted) {
        if (_searchController.text.isNotEmpty) {
          _hasTypedInSearch = true;
          setState(() {});
        } else {
          if (_hasTypedInSearch) {
            _toggleSearch();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  //Criação de Widgets
  Widget _buildFileListView(List<File> files) {
    if (_isLoading && files.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (files.isEmpty) {
      return const Center(child: Text("Nenhum arquivo encontrado", style: TextStyle(fontSize: 16)));
    }

    Set<List<String>> filtersForIcon = {};
    for (var filter in GlobalSettings.docTypeFilters) {
      final convertedFilter = FilterParser.parseFilter(filter);
      if (convertedFilter.isNotEmpty) {
        filtersForIcon.add(convertedFilter);
      }
      debugPrint(convertedFilter.toString());
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final title = path.basename(files[index].path);
        final bool isSent = _sentStatus[files[index].path] ?? false;
        String? subtitle;
        Icon icon = Icon(Icons.insert_drive_file, color: Colors.amberAccent);
        for (var filter in filtersForIcon) {
          final fileType = filter[0].toUpperCase();
          final operationType = filter[1].toUpperCase();
          final occurrence = filter[2];

          bool match = false;
          switch (operationType) {
            case "CONTAINS":
              match = title.toUpperCase().contains(occurrence.toUpperCase());
              break;
            case "REGEX":
              try {
                match = RegExp(occurrence, caseSensitive: false).hasMatch(title);
              } catch (e) {
                debugPrint("Invalid regex in filter: '$occurrence'. Error: $e");
              }
              break;
          }
          if (match) {
            switch (fileType) {
              case "FISCAL_NOTE":
                icon = Icon(Icons.receipt_long_outlined, color: isSent ? Colors.greenAccent : Colors.red);
                subtitle = _tagPossibleFiscalNoteType;
                break;
              case "REPORT":
                icon = Icon(Icons.note_alt_outlined);
                subtitle = _tagPossibleReportType;
                break;
              case "BONUS":
                icon = Icon(Icons.monetization_on_outlined, color: Colors.yellowAccent);
                subtitle = _tagPossibleBonus;
                break;
              case "PAID":
                icon = Icon(Icons.payment_outlined, color: Colors.green);
                subtitle = _tagPossiblePaid;
                break;
            }
            break;
          }
        }

        return FileItem(title: title, subtitle: subtitle, icon: icon);
      },
    );
  }

  void _toggleFabMenu() {
    if (_fabAnimationController.isDismissed) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  Widget _buildFloatintActionButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _fabAnimationController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton.small(
              heroTag: "settings_fab",
              tooltip: 'Configurações',
              onPressed: () {
                _toggleFabMenu();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsActivity()));
              },
              child: const Icon(Icons.settings),
            ),
          ),
        ),
        ScaleTransition(
          scale: _fabAnimationController,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton.small(
              heroTag: "sync_fab",
              tooltip: 'Sincronizar',
              onPressed: () {
                _toggleFabMenu();
                if (!_isLoading) _updateLocalFiles();
              },
              child: const Icon(Icons.sync),
            ),
          ),
        ),
        FloatingActionButton(
          heroTag: "main_fab",
          onPressed: _toggleFabMenu,
          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 0.375).animate(_fabAnimationController),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  //Atualização da lista de arquivos e sincronização com IMAP
  Future<void> _updateLocalFiles() async {
    final Directory targetDir = Directory(GlobalSettings.analyzeFilesPath);
    if (targetDir.existsSync()) {
      setState(() {
        _isLoading = true;
        _sentStatus.clear(); // Limpa o status anterior antes de recarregar

        // Lista os arquivos e já os ordena pelo nome do arquivo (A-Z)
        final files = targetDir.listSync(recursive: true).whereType<File>().toList();
        files.sort((a, b) => path.basename(a.path).toLowerCase().compareTo(path.basename(b.path).toLowerCase()));
        filesList = files;
      });
      await _checkFilesSentStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Diretório de análise não encontrado: ${GlobalSettings.analyzeFilesPath}")),
      );
    }
  }

  Future<void> _checkFilesSentStatus() async {
    try {
      final sentAttachmentNames = await _mailService.fetchAllSentAttachmentNames();

      final newStatus = <String, bool>{};
      for (final file in filesList) {
        final localFileName = path.basename(file.path).toLowerCase();
        newStatus[file.path] = sentAttachmentNames.contains(localFileName);
      }

      setState(() {
        _sentStatus = newStatus;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sincronizar: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  //Alternador no estado de pesquisa
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _hasTypedInSearch = false;
        _searchController.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Text("data"),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.code),
                  title: Text("XMLs"),
                  onTap: () {
                    Navigator.pushNamed(context, AppRouters.xmls);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.toLowerCase();

    // Calcula as listas filtradas uma vez para otimizar o desempenho.
    final sentFiles = filesList.where((file) => _sentStatus[file.path] == true).toList();
    final unsentFiles = filesList.where((file) => _sentStatus[file.path] != true).toList();

    final geralFiles = filesList.where((file) {
      return !_isSearching ? true : path.basename(file.path).toLowerCase().contains(searchQuery);
    }).toList();

    if (_isSearching) {
      _tabController?.index = 0;
    }

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              )
            : _isLoading
            ? Row(
                children: [
                  SizedBox(
                    width: 20,

                    height: 20,
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  SizedBox(width: 16),
                  Text("Sincronizando..."),
                ],
              )
            : Text(_appTitle),
        actions: [IconButton(onPressed: _toggleSearch, icon: Icon(_isSearching ? Icons.close : Icons.search))],
        bottom: _isSearching
            ? Tab(
                child: Text(
                  "Resultados da pesquisa: ${geralFiles.length}",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
                ),
              )
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: "Todos (${geralFiles.length})"),
                  Tab(text: "Enviados (${sentFiles.length})"),
                  Tab(text: "Não Enviados (${unsentFiles.length})"),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), Text("Conectando ao servidor IMAP")],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFileListView(geralFiles),
                _buildFileListView(sentFiles),
                _buildFileListView(unsentFiles),
              ],
            ),
      floatingActionButton: _buildFloatintActionButton(),
    );
  }
}

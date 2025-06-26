import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/service/mail/mail_service.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/settings/settings_activity.dart';
import 'package:myapp/utils/theme_notifier.dart';
import 'package:myapp/widgets/list/file_item.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necessário para usar await antes do runApp
  await GlobalSettings.init(); // <- Aqui você inicializa sua classe

  // Carrega o tema salvo antes de iniciar o app
  final initialThemeMode = ThemeMode.values[GlobalSettings.themeMode];

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(initialThemeMode),
      child: const NFObserverApp(),
    ),
  );
}

class NFObserverApp extends StatelessWidget {
  const NFObserverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'NFObserver App',
      debugShowCheckedModeBanner: kDebugMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey.shade100,

        colorScheme: ColorScheme.light(
          primary: Colors.blue.shade800,
          secondary: Colors.teal.shade400,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: const Color.fromARGB(210, 255, 255, 255),
          onSurface: Colors.black,
          error: Colors.red.shade700,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white, // Cor para título e ícones
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal.shade400,
          foregroundColor: Colors.white,
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
        ),
      ),
      // Tema para o modo escuro
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade300,
          secondary: Colors.teal.shade200,
          surface: const Color(0xFF1E1E1E),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal.shade200,
          foregroundColor: Colors.black,
        ),
      ),
      themeMode: themeNotifier.themeMode,
      home: const NFObserverPage(title: 'NFObserver'),
    );
  }
}

class NFObserverPage extends StatefulWidget {
  const NFObserverPage({super.key, required this.title});

  final String title;
  @override
  State<NFObserverPage> createState() => _NFObserverPageState();
}

class _NFObserverPageState extends State<NFObserverPage>
    with TickerProviderStateMixin {
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

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

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
      return const Center(
        child: Text(
          "Nenhum arquivo encontrado",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSent = _sentStatus[file.path] ?? false;
        return FileItem(
          file: file,
          isSent: isSent,
          subtitleFilter: (file) {
            final fileName = path.basename(file.path);
            return fileName.contains(RegExp('NF \\d*'))
                ? "Possível Nota Fiscal"
                : RegExp(
                    r'^((\d{2}|\d{2}-\d{2})\.\d{2}\.\d{2})',
                  ).hasMatch(fileName)
                ? "Possível anotação/relatório"
                : path
                      .dirname(file.path)
                      .replaceFirst(GlobalSettings.analyzeFilesPath, "");
          },
        );
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsActivity(),
                  ),
                );
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
            turns: Tween(
              begin: 0.0,
              end: 0.375,
            ).animate(_fabAnimationController),
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
        final files = targetDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList();
        files.sort(
          (a, b) => path
              .basename(a.path)
              .toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase()),
        );
        filesList = files;
      });
      await _checkFilesSentStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Diretório de análise não encontrado: ${GlobalSettings.analyzeFilesPath}",
          ),
        ),
      );
    }
  }

  Future<void> _checkFilesSentStatus() async {
    try {
      final sentAttachmentNames = await _mailService
          .fetchAllSentAttachmentNames();

      final newStatus = <String, bool>{};
      for (final file in filesList) {
        final localFileName = path.basename(file.path).toLowerCase();
        newStatus[file.path] = sentAttachmentNames.contains(localFileName);
      }

      setState(() {
        _sentStatus = newStatus;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao sincronizar: $e")));
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

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.toLowerCase();

    // Calcula as listas filtradas uma vez para otimizar o desempenho.
    final sentFiles = filesList
        .where((file) => _sentStatus[file.path] == true)
        .toList();
    final unsentFiles = filesList
        .where((file) => _sentStatus[file.path] != true)
        .toList();

    final geralFiles = filesList.where((file) {
      return !_isSearching
          ? true
          : path.basename(file.path).toLowerCase().contains(searchQuery);
    }).toList();

    if (_isSearching) {
      _tabController?.index = 0;
    }

    return Scaffold(
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
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text("Sincronizando..."),
                ],
              )
            : Text(widget.title),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_isSearching ? Icons.close : Icons.search),
          ),
        ],
        bottom: _isSearching
            ? Tab(
                child: Text(
                  "Resultados da pesquisa: ${geralFiles.length}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
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
      body: TabBarView(
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

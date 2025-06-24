import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myapp/service/mail/mail_service.dart';
import 'package:myapp/settings/global.dart';
import 'package:myapp/settings/settings_activity.dart';
import 'package:myapp/widgets/list/file_item.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necessário para usar await antes do runApp
  await GlobalSettings.init(); // <- Aqui você inicializa sua classe

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFObserver App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'NFObserver'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  List<File> filesList = [];
  Map<String, bool> _sentStatus = {};
  bool _isLoading = false;
  final _mailService = MailService();

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateLocalFiles();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

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

  void syncronizeFiles() {}

  @override
  Widget build(BuildContext context) {
    // Calcula as listas filtradas uma vez para otimizar o desempenho.
    final sentFiles = filesList
        .where((file) => _sentStatus[file.path] == true)
        .toList();
    final unsentFiles = filesList
        .where((file) => _sentStatus[file.path] != true)
        .toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                widget.title,
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              title: const Text("Configurações"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsActivity(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: _isLoading
            ? const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(width: 16),
                  Text("Sincronizando..."),
                ],
              )
            : Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Todos (${filesList.length})"),
            Tab(text: "Enviados (${sentFiles.length})"),
            Tab(text: "Não Enviados (${unsentFiles.length})"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFileListView(filesList),
          _buildFileListView(sentFiles),
          _buildFileListView(unsentFiles),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isLoading ? null : _updateLocalFiles,
            child: Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

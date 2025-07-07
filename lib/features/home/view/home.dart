import 'package:flutter/material.dart';
import 'package:nfobserver/features/app_routers.dart';
import 'package:nfobserver/features/home/provider/nf_provider.dart';
import 'package:nfobserver/models/consolidated_nf.dart';
import 'package:nfobserver/features/home/widgets/nf_list_tile.dart';
import 'package:nfobserver/features/settings/view/settings_activity.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final _appTitle = "NF Observer";

  //Pesquisa
  bool _isSearching = false;
  final _searchController = TextEditingController();

  //Filtragem
  TabController? _tabController;

  //Animação do FloatingButton
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fabAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    // Inicia o carregamento dos dados consolidados assim que a tela é construída.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NFProvider>();
      if (provider.consolidatedList.isEmpty && !provider.isLoading) {
        provider.loadAndConsolidateData();
      }
    });

    // Adiciona um listener para reconstruir a tela ao digitar na busca.
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _toggleFabMenu() {
    if (_fabAnimationController.isDismissed) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  Widget _buildFloatingActionButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _fabAnimationController,
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
        const SizedBox(height: 16),
        ScaleTransition(
          scale: _fabAnimationController,
          child: FloatingActionButton.small(
            heroTag: "sync_fab",
            tooltip: 'Atualizar',
            onPressed: () {
              _toggleFabMenu();
              context.read<NFProvider>().loadAndConsolidateData();
            },
            child: const Icon(Icons.sync),
          ),
        ),
        const SizedBox(height: 16),
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        FocusScope.of(context).unfocus();
      }
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Text(
              _appTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text("XMLs (Visão Antiga)"),
            onTap: () {
              Navigator.pop(context); // Fecha o drawer
              Navigator.pushNamed(context, AppRouters.xmls);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nfProvider = context.watch<NFProvider>();
    final searchQuery = _searchController.text.toLowerCase();

    // Filtra a lista principal com base na pesquisa.
    final searchFilteredList = nfProvider.consolidatedList.where((nf) {
      if (!_isSearching || searchQuery.isEmpty) return true;

      final docName = nf.docData.name?.toLowerCase() ?? '';
      final supplier = nf.xmlData?.emitName.toLowerCase() ?? '';
      final nfNumber = nf.xmlData?.nfNumber.toString() ?? '';

      return docName.contains(searchQuery) || supplier.contains(searchQuery) || nfNumber.contains(searchQuery);
    }).toList();

    // Cria as listas para cada aba a partir da lista já filtrada pela pesquisa.
    final sentFiles = searchFilteredList.where((nf) => nf.isSent).toList();
    final unsentFiles = searchFilteredList.where((nf) => !nf.isSent).toList();

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
            : nfProvider.isEnriching
            ? Text(
                nfProvider.statusMessage,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
              )
            : Text(_appTitle),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_isSearching ? Icons.close : Icons.search),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(nfProvider.isEnriching ? 52.0 : 48.0),
          child: Column(
            children: [
              if (nfProvider.isEnriching)
                const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              if (_isSearching)
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(
                    "Resultados da pesquisa: ${searchFilteredList.length}",
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              else
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Text("Todos (${searchFilteredList.length})", overflow: TextOverflow.ellipsis),
                    ),
                    Tab(text: "Enviados (${sentFiles.length})"),
                    Tab(text: "Não Enviados (${unsentFiles.length})"),
                  ],
                ),
            ],
          ),
        ),
      ),
      body: _buildBody(nfProvider, searchFilteredList, sentFiles, unsentFiles),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody(
    NFProvider provider,
    List<ConsolidatedNF> allFiles,
    List<ConsolidatedNF> sentFiles,
    List<ConsolidatedNF> unsentFiles,
  ) {
    if (provider.isLoading && provider.consolidatedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(provider.statusMessage),
          ],
        ),
      );
    }

    // Se a busca estiver ativa, mostramos apenas a lista de resultados.
    // Caso contrário, mostramos a TabBarView.
    return _isSearching
        ? _buildConsolidatedListView(provider, allFiles)
        : TabBarView(
            controller: _tabController,
            children: [
              _buildConsolidatedListView(provider, allFiles),
              _buildConsolidatedListView(provider, sentFiles),
              _buildConsolidatedListView(provider, unsentFiles),
            ],
          );
  }

  /// Constrói uma lista de documentos com base nos itens fornecidos.
  Widget _buildConsolidatedListView(NFProvider provider, List<ConsolidatedNF> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          _isSearching ? 'Nenhum resultado para a busca' : 'Nenhum item nesta categoria',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadAndConsolidateData(),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return NFListTile(nf: items[index]);
        },
      ),
    );
  }
}

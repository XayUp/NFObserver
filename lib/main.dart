import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfobserver/features/app_routers.dart';
import 'package:nfobserver/features/home/provider/nf_provider.dart';
import 'package:nfobserver/features/settings/variables/global.dart';
import 'package:nfobserver/utils/theme_notifier.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necessário para usar await antes do runApp
  await GlobalSettings.init(); // <- Aqui você inicializa sua classe

  // Carrega o tema salvo antes de iniciar o app
  final initialThemeMode = ThemeMode.values[await ThemeNotifier.getThemeIndex()];

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(initialThemeMode)),
        ChangeNotifierProvider(create: (_) => NFProvider()),
      ],
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
        tabBarTheme: TabBarThemeData(labelColor: Colors.white, unselectedLabelColor: Colors.white54),
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
      routes: AppRouters.routers,
      initialRoute: AppRouters.home,
    );
  }
}

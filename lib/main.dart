import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LogPreviewApp());
}

class LogPreviewApp extends StatelessWidget {
  const LogPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日志查看器',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // 默认暗色主题，适合开发者
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF252526),
          elevation: 0,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

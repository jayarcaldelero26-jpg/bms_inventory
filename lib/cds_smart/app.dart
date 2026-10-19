import 'package:flutter/material.dart';

import 'ui_components.dart';
import 'auth_screens.dart';
import 'demo_screens.dart';

class CdsSmartApp extends StatelessWidget {
  const CdsSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiOrigin = const String.fromEnvironment('CDS_API_BASE_URL');
    final baseUrl = apiOrigin.isEmpty ? null : Uri.tryParse(apiOrigin);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff176b43),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'CDS-SMART Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xfff4f7f5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff176b43),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xffe4ebe6)),
          ),
        ),
      ),
      home: const bool.fromEnvironment('CDS_DEMO_MODE')
          ? const CdsDemoHome()
          : CdsSmartHome(baseUrl: baseUrl),
    );
  }
}

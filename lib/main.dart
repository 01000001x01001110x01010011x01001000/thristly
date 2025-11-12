import 'package:flutter/material.dart';
import 'main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThristifyApp());
}

class ThristifyApp extends StatelessWidget {
  const ThristifyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'thristify',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        home: const MainScaffold(),
      );
}

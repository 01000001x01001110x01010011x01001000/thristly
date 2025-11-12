import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/task_planner_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TaskPlannerPage(),
  ];

  void _onTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Reminders'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
        ],
      ),
    );
  }
}

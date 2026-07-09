import 'package:flutter/material.dart';

import '../body/body_page.dart';
import '../profile/profile_page.dart';
import '../workout/plans_page.dart';
import 'today_home_page.dart';

/// App shell with the bottom navigation. IndexedStack keeps each tab's state
/// (scroll position, loaded data) alive when switching.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    TodayHomePage(),
    PlansPage(),
    BodyPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: '今天', tooltip: ''),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '计划', tooltip: ''),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '数据', tooltip: ''),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的', tooltip: ''),
        ],
      ),
    );
  }
}

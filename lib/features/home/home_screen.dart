import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/analytics/analytics_screen.dart';
import 'package:fileflow/features/files/files_screen.dart';
import 'package:fileflow/features/rules/rules_screen.dart';
import 'package:fileflow/features/settings/settings_screen.dart';
import 'package:fileflow/features/swipe_cleanup/swipe_cleanup_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.swipe_outlined),
      selectedIcon: Icon(Icons.swipe),
      label: 'Cleanup',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: 'Files',
    ),
    NavigationDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: 'Rules',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Analytics',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  static const _screens = [
    SwipeCleanupScreen(),
    FilesScreen(),
    RulesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: _destinations,
          backgroundColor: AppColors.surface,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}

/// HomeShell — wraps the StatefulNavigationShell (go_router's indexed-stack
/// shell) with the floating PillTabBar at the bottom.
///
/// The tab bar is NOT rendered by Profile or Room Detail — those screens
/// are pushed outside the shell route entirely, so the tab bar is
/// automatically absent without any manual show/hide logic.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'pill_tab_bar.dart';
// Sheets are imported lazily when needed (not yet implemented)

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // extendBody allows the shell content to render behind the tab bar
      // (so the last list item doesn't sit right above the pill)
      extendBody: true,
      body: shell,
      bottomNavigationBar: PillTabBar(
        currentIndex: shell.currentIndex,
        onTabSelected: (index) {
          // goBranch with initialLocation: true resets the branch's navigation
          // stack, matching normal bottom-tab behaviour
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
        onAddPressed: () {
          // TODO: show ExpenseTypeSheet bottom sheet
          // Will be implemented in the Add Expense feature.
          _showComingSoon(context, 'Add expense');
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming next sprint'),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

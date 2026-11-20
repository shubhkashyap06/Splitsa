/// HomeShell — wraps go_router's indexed-stack shell with the floating
/// PillTabBar. Profile is pushed outside the shell, so the tab bar is
/// absent there without any manual show/hide logic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/expenses/presentation/add_flow.dart';
import 'pill_tab_bar.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: shell,
      bottomNavigationBar: PillTabBar(
        currentIndex: shell.currentIndex,
        onTabSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        onAddPressed: () => startAddFlow(context, ref),
      ),
    );
  }
}

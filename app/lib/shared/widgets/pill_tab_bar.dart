/// PillTabBar — the floating black pill tab bar from UI_UX_SPEC.md §2.
///
/// Behaviour:
///   • 5 icon-only tabs: Home / Rooms / Add (raised, marigold) / Pots / Insights
///   • Active tab's icon sits inside a white circular bubble that
///     springs/slides between icons on tab change — never a hard cut
///   • The Add (index 2) button is always a raised marigold circle, does NOT
///     participate in the active-bubble system — it calls [onAddPressed] instead
///   • Tapped icon does a small bounce-scale (spring press)
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_durations.dart';
import '../../../core/theme/app_spacing.dart';

enum _Tab { home, rooms, add, pots, insights }

const _tabIcons = [
  Icons.home_outlined,
  Icons.group_outlined,
  Icons.add,             // Add — handled separately
  Icons.savings_outlined,
  Icons.insights_outlined,
];

const _tabActiveIcons = [
  Icons.home_rounded,
  Icons.group_rounded,
  Icons.add,
  Icons.savings_rounded,
  Icons.bar_chart_rounded,
];

class PillTabBar extends StatefulWidget {
  const PillTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  /// 0=Home, 1=Rooms, 2=Add (never set as active), 3=Pots, 4=Insights
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  @override
  State<PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<PillTabBar> with TickerProviderStateMixin {
  // Spring animation for the sliding bubble
  late AnimationController _bubbleController;
  late Animation<double> _bubblePosition; // 0.0 to 1.0 across the bar

  // Per-tab bounce controllers
  final _bounceControllers = <AnimationController>[];

  // Previous non-add index for bubble position tracking
  late int _prevIndex;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex == 2 ? 0 : widget.currentIndex;

    _bubbleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _bubblePosition = Tween<double>(begin: _indexToFraction(_prevIndex), end: _indexToFraction(_prevIndex))
        .animate(CurvedAnimation(parent: _bubbleController, curve: AppCurves.bounce));

    for (int i = 0; i < 5; i++) {
      _bounceControllers.add(AnimationController(
        vsync: this,
        duration: AppDurations.veryFast,
        lowerBound: 0.88,
        upperBound: 1.0,
        value: 1.0,
      ));
    }
  }

  @override
  void didUpdateWidget(PillTabBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && widget.currentIndex != 2) {
      _animateBubbleTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    for (final c in _bounceControllers) { c.dispose(); }
    super.dispose();
  }

  void _animateBubbleTo(int index) {
    final fromFraction = _indexToFraction(_prevIndex);
    final toFraction   = _indexToFraction(index);
    _bubblePosition = Tween<double>(begin: fromFraction, end: toFraction)
        .animate(CurvedAnimation(parent: _bubbleController, curve: AppCurves.bounce));
    _bubbleController
      ..reset()
      ..forward();
    _prevIndex = index;
  }

  /// Maps tab index → fraction of bar width (0 = leftmost centre, 1 = rightmost centre).
  /// Index 2 (Add) is skipped — the bubble never sits there.
  double _indexToFraction(int index) {
    // Slots: 0.1, 0.3, (0.5 = Add, skipped), 0.7, 0.9
    const fractions = [0.1, 0.3, 0.5, 0.7, 0.9];
    return fractions[index.clamp(0, 4)];
  }

  void _onTabTap(int index) {
    if (index == 2) {
      _triggerBounce(2);
      widget.onAddPressed();
      return;
    }
    if (index == widget.currentIndex) return;
    _triggerBounce(index);
    widget.onTabSelected(index);
  }

  void _triggerBounce(int index) async {
    final ctrl = _bounceControllers[index];
    await ctrl.reverse();
    ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: AppSpacing.xl,
      ),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.tabBarBg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.tabBarBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LayoutBuilder(builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            return Stack(
              alignment: Alignment.center,
              children: [
                // ── Sliding white bubble ─────────────────────────────────
                AnimatedBuilder(
                  animation: _bubblePosition,
                  builder: (context, _) {
                    if (widget.currentIndex == 2) {
                      // No bubble while Add is "active"
                      return const SizedBox.shrink();
                    }
                    final bubbleX = _bubblePosition.value * barWidth - barWidth / 2;
                    return Transform.translate(
                      offset: Offset(bubbleX, 0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                      ),
                    );
                  },
                ),

                // ── Tab icons ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final isAdd    = index == 2;
                    final isActive = !isAdd && index == widget.currentIndex;
                    return _TabButton(
                      index:        index,
                      isAdd:        isAdd,
                      isActive:     isActive,
                      icon:         isActive ? _tabActiveIcons[index] : _tabIcons[index],
                      bounceCtrl:   _bounceControllers[index],
                      onTap:        () => _onTabTap(index),
                    );
                  }),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.index,
    required this.isAdd,
    required this.isActive,
    required this.icon,
    required this.bounceCtrl,
    required this.onTap,
  });
  final int index;
  final bool isAdd;
  final bool isActive;
  final IconData icon;
  final AnimationController bounceCtrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: bounceCtrl,
        child: SizedBox(
          width: 56,
          height: 68,
          child: Center(
            child: isAdd
                ? _AddButton(icon: icon)
                : Icon(
                    icon,
                    size: 22,
                    color: isActive ? AppColors.black : AppColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.marigold,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: [
          BoxShadow(
            color: AppColors.marigold.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: AppColors.black),
    );
  }
}

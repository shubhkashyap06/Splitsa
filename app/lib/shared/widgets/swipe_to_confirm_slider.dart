/// SwipeToConfirmSlider — reserve this ONLY for money-moving actions (Settle Up).
/// Every other action in the app uses a tap button.
///
/// Ported from the reference prototype's SwipeToConfirm component (ui.tsx).
/// Behaviour: pill-shaped track, white knob with arrow icon on left edge.
/// As the knob is dragged, the track fills with [accentColor].
/// Resistance easing near the end of the track (dragElastic equivalent).
/// On release past 82% → snaps forward, icon flips to check mark, [onConfirm] fires.
/// On release below 82% → springs back to start.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_durations.dart';

class SwipeToConfirmSlider extends StatefulWidget {
  const SwipeToConfirmSlider({
    super.key,
    required this.onConfirm,
    this.label = 'Swipe right to confirm',
    this.accentColor = AppColors.marigold,
  });

  final VoidCallback onConfirm;
  final String label;
  final Color accentColor;

  @override
  State<SwipeToConfirmSlider> createState() => _SwipeToConfirmSliderState();
}

class _SwipeToConfirmSliderState extends State<SwipeToConfirmSlider>
    with SingleTickerProviderStateMixin {
  static const double _knobSize = 56.0;
  static const double _trackHeight = 68.0;
  static const double _threshold = 0.82; // fraction of max drag to trigger

  double _dragX = 0;
  double _maxDrag = 0;
  bool _confirmed = false;

  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(vsync: this, duration: AppDurations.fast);
    _snapCtrl.addListener(() => setState(() => _dragX = _snapAnim.value));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    _snapCtrl.stop();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_confirmed) return;
    setState(() {
      // Elastic resistance near end of track
      final progress = (_dragX / _maxDrag).clamp(0.0, 1.0);
      final resistance = progress > 0.85 ? 0.15 : 1.0;
      _dragX = (_dragX + d.delta.dx * resistance).clamp(0, _maxDrag);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_confirmed) return;
    final progress = _dragX / _maxDrag;
    if (progress >= _threshold) {
      // Snap forward, then confirm
      _snapAnim = Tween<double>(begin: _dragX, end: _maxDrag)
          .animate(CurvedAnimation(parent: _snapCtrl, curve: AppCurves.springy));
      _snapCtrl.reset();
      _snapCtrl.forward();
      setState(() => _confirmed = true);
      HapticFeedback.mediumImpact();
      Future.delayed(AppDurations.fast, widget.onConfirm);
    } else {
      // Spring back to start
      _snapAnim = Tween<double>(begin: _dragX, end: 0)
          .animate(CurvedAnimation(parent: _snapCtrl, curve: AppCurves.bounce));
      _snapCtrl.reset();
      _snapCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - _knobSize - 8;
        final fillWidth = (_dragX + _knobSize + 4).clamp(0, constraints.maxWidth).toDouble();
        final labelOpacity = (1.0 - (_dragX / (_maxDrag * 0.6))).clamp(0.0, 1.0);

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: const Color(0x11FFFFFF), // 7% white
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Fill that travels with knob
              AnimatedContainer(
                duration: Duration.zero,
                width: fillWidth,
                height: _trackHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withOpacity(0.7),
                      widget.accentColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),

              // Label (fades as knob moves right)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: _confirmed ? 0 : labelOpacity,
                      child: Text(
                        widget.label.toUpperCase(),
                        style: AppTextStyles.labelCaps,
                      ),
                    ),
                  ),
                ),
              ),

              // Draggable knob
              Positioned(
                left: 4 + _dragX,
                top: (_trackHeight - _knobSize) / 2,
                child: GestureDetector(
                  onPanStart:  _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd:    _onPanEnd,
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      color: AppColors.black,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Bring spacing into scope for this file
abstract final class AppSpacing {
  static const double radiusPill = 100.0;
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class SettleSheet extends StatefulWidget {
  const SettleSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettleSheet(),
    );
  }

  @override
  State<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<SettleSheet> with TickerProviderStateMixin {
  String _amount = '230';
  bool _done = false;

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
      } else {
        if (_amount.length < 7) _amount += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayAmount = _amount.isEmpty ? '0' : _amount;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ListView(
            controller: controller,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8DB),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _done ? _buildSuccess() : _buildEntry(displayAmount),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntry(String displayAmount) {
    return Column(
      key: const ValueKey('entry'),
      children: [
        // Recipient Chip
        Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AvatarWidget(name: 'Aditi', tone: AppColors.marigold, size: 26),
                const SizedBox(width: 8),
                const Text('Aditi · UPI ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF888888)),
              ],
            ),
          ),
        ),
        
        // Amount
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxxl, bottom: AppSpacing.xxl),
          child: Column(
            children: [
              RichText(
                text: TextSpan(
                  text: '₹',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                  children: [
                    TextSpan(
                      text: displayAmount,
                      style: const TextStyle(fontSize: 46),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Available ₹7,854.43',
                style: TextStyle(fontSize: 13, color: Color(0xFFA0A0A5), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        _buildOperatorRow(),
        const SizedBox(height: AppSpacing.md),
        _buildNumberPad(),
        const SizedBox(height: AppSpacing.xxxl),
        
        SwipeToConfirm(
          onConfirm: () => setState(() => _done = true),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 60),
        Stack(
          alignment: Alignment.center,
          children: [
            const _Confetti(),
            Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: AppColors.marigold, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('Settled! 🎉', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                const SizedBox(height: 4),
                const Text("Your potli's looking lighter", style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperatorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['+', '−', '×', '÷'].map((op) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 44, height: 44,
          decoration: const BoxDecoration(color: Color(0xFFF0F0F2), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(op, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
        ),
      )).toList(),
    );
  }

  Widget _buildNumberPad() {
    final keys = ['1','2','3','4','5','6','7','8','9','.','0','back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: keys.map((k) {
        return GestureDetector(
          onTap: () => _onKey(k),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF0F0F2), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: k == 'back'
                ? const Icon(Icons.backspace_outlined, size: 22, color: Color(0xFF555555))
                : Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
          ),
        );
      }).toList(),
    );
  }
}

class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({super.key, required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> {
  double _dragValue = 0.0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 56;
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  _confirmed ? 'Confirmed' : 'Swipe to pay',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white54),
                ),
              ),
              AnimatedPositioned(
                duration: _dragValue == 0 ? const Duration(milliseconds: 250) : Duration.zero,
                curve: Curves.easeOut,
                left: _dragValue,
                top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_confirmed) return;
                    setState(() {
                      _dragValue += details.delta.dx;
                      if (_dragValue < 0) _dragValue = 0;
                      if (_dragValue >= maxDrag) {
                        _dragValue = maxDrag;
                        _confirmed = true;
                        widget.onConfirm();
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (!_confirmed) {
                      setState(() => _dragValue = 0);
                    }
                  },
                  child: Container(
                    width: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.marigold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 18),
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

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _random = math.Random();
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _particles = List.generate(20, (i) => _ConfettiParticle(_random, i));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: 300,
          height: 200,
          child: CustomPaint(
            painter: _ConfettiPainter(_particles, _ctrl.value),
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double xOffset;
  final double delay;
  final double speed;
  final Color color;
  final bool petal;

  _ConfettiParticle(math.Random r, int index)
      : xOffset = r.nextDouble() * 200 - 100,
        delay = r.nextDouble() * 0.2,
        speed = 1.0 + r.nextDouble(),
        petal = index % 2 == 0,
        color = [AppColors.marigold, AppColors.rust, const Color(0xFF2F9E8F), Colors.grey][index % 4];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final pProgress = math.max(0.0, (progress - p.delay) / (1 - p.delay));
      if (pProgress == 0 || pProgress >= 1) continue;
      
      final y = -20 + (pProgress * 250 * p.speed);
      final x = (size.width / 2) + p.xOffset;
      final opacity = 1.0 - math.pow(pProgress, 2);
      
      paint.color = p.color.withValues(alpha: opacity as double);
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pProgress * math.pi * 4); // spin
      if (p.petal) {
        final path = Path()..addArc(Rect.fromCircle(center: Offset.zero, radius: 6), 0, math.pi * 1.5);
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset.zero, 5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

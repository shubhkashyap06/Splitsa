import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/avatar_widget.dart';

/// SettleSheet — "Settle up" bottom sheet.
///
/// UI flow:
///   1. Edit amount (optional) + choose UPI app
///   2. Swipe to confirm → launches UPI deep link → success state
///
/// UPI deep link format (per docs/PRODUCT_LOGIC.md §5):
///   upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>&tr=<ref>
class SettleSheet extends StatefulWidget {
  const SettleSheet({
    super.key,
    this.payeeName = 'Aditi',
    this.payeeUpiId = 'aditi@okicici',
    this.amountPaise = 23000,
    this.roomName = 'Flat 4B',
    this.transactionRef,
  });

  final String payeeName;
  final String payeeUpiId;
  final int amountPaise;
  final String roomName;
  final String? transactionRef;

  static Future<void> show(BuildContext context, {
    String payeeName = 'Aditi',
    String payeeUpiId = 'aditi@okicici',
    int amountPaise = 23000,
    String roomName = 'Flat 4B',
    String? transactionRef,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => SettleSheet(
        payeeName: payeeName,
        payeeUpiId: payeeUpiId,
        amountPaise: amountPaise,
        roomName: roomName,
        transactionRef: transactionRef,
      ),
    );
  }

  @override
  State<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<SettleSheet> {
  late String _display;
  bool _done = false;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    final rupees = widget.amountPaise ~/ 100;
    _display = rupees.toString();
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_display.isNotEmpty) _display = _display.substring(0, _display.length - 1);
        return;
      }
      if (key == '.' && _display.contains('.')) return;
      if (_display.length < 7) _display += key;
    });
  }

  int get _totalPaise {
    final rupees = double.tryParse(_display) ?? 0;
    return (rupees * 100).round();
  }

  String get _formattedAmount {
    final rupees = _totalPaise / 100;
    if (rupees == rupees.truncateToDouble()) return rupees.toInt().toString();
    return rupees.toStringAsFixed(2);
  }

  // ── UPI deep link ────────────────────────────────────────────────────────

  Uri _buildUpiUri({String? appPackage}) {
    final ref = widget.transactionRef ?? 'splitsa_${DateTime.now().millisecondsSinceEpoch}';
    final note = Uri.encodeComponent('Splitsa: ${widget.roomName} settle');
    return Uri.parse(
      'upi://pay'
      '?pa=${widget.payeeUpiId}'
      '&pn=${Uri.encodeComponent(widget.payeeName)}'
      '&am=$_formattedAmount'
      '&cu=INR'
      '&tn=$note'
      '&tr=$ref'
    );
  }

  Future<void> _launchUpi() async {
    setState(() => _launching = true);
    final uri = _buildUpiUri();
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (launched) {
        setState(() { _done = true; _launching = false; });
      } else {
        // UPI not supported (iOS / web) — show copy fallback
        _showUpiCopyFallback();
        setState(() => _launching = false);
      }
    } on PlatformException {
      if (!mounted) return;
      _showUpiCopyFallback();
      setState(() => _launching = false);
    }
  }

  void _showUpiCopyFallback() {
    Clipboard.setData(ClipboardData(text: widget.payeeUpiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID "${widget.payeeUpiId}" copied — open your UPI app manually'),
        action: SnackBarAction(
          label: 'Done',
          onPressed: () => setState(() => _done = true),
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 6,
              decoration: BoxDecoration(color: const Color(0xFFD8D8DB), borderRadius: BorderRadius.circular(100)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(animation), child: child)),
                child: _done ? _buildSuccess() : _buildEntry(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry() {
    return Padding(
      key: const ValueKey('entry'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          // Payee chip
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SplitsaAvatar(name: widget.payeeName, tone: AppColors.marigold, size: 26),
                const SizedBox(width: 8),
                Text('${widget.payeeName} · ${widget.payeeUpiId}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.payeeUpiId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI ID copied'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                    );
                  },
                  child: const Icon(Icons.copy, size: 14, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),

          // Amount
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    text: '₹',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                    children: [
                      TextSpan(
                        text: _display.isEmpty ? '0' : _display,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showUpiCopyFallback,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 13, color: Color(0xFFAAAAAA)),
                      const SizedBox(width: 4),
                      Text('Copy UPI ID instead',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA), decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Numpad
          _SettleNumpad(onKey: _onKey),
          const SizedBox(height: AppSpacing.xxl),

          // UPI App buttons
          _UpiAppRow(
            onAppSelected: (app) async {
              setState(() => _launching = true);
              final ref = widget.transactionRef ?? 'splitsa_${DateTime.now().millisecondsSinceEpoch}';
              // Some apps support pa= query for direct routing
              final uri = Uri.parse(
                'upi://pay'
                '?pa=${widget.payeeUpiId}'
                '&pn=${Uri.encodeComponent(widget.payeeName)}'
                '&am=$_formattedAmount'
                '&cu=INR'
                '&tn=${Uri.encodeComponent('Splitsa: ${widget.roomName} settle')}'
                '&tr=$ref'
                '${app.packageParam != null ? '&app=${app.packageParam}' : ''}'
              );
              try {
                final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!mounted) return;
                if (launched) {
                  setState(() { _done = true; _launching = false; });
                } else {
                  _showUpiCopyFallback();
                  setState(() => _launching = false);
                }
              } catch (_) {
                if (!mounted) return;
                _showUpiCopyFallback();
                setState(() => _launching = false);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Swipe to confirm
          _SwipeToConfirm(
            loading: _launching,
            onConfirm: _launchUpi,
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Stack(
            alignment: Alignment.center,
            children: [
              const _Confetti(),
              Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: AppColors.marigold, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text('Settled! 🎉',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                  const SizedBox(height: 6),
                  Text("Paid ₹$_formattedAmount to ${widget.payeeName}",
                    style: const TextStyle(fontSize: 15, color: Color(0xFF888888))),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => context.pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── UPI App Row ───────────────────────────────────────────────────────────────

class _UpiApp {
  const _UpiApp({required this.name, required this.emoji, this.packageParam});
  final String name;
  final String emoji;
  final String? packageParam;
}

class _UpiAppRow extends StatelessWidget {
  const _UpiAppRow({required this.onAppSelected});
  final ValueChanged<_UpiApp> onAppSelected;

  static const _apps = [
    _UpiApp(name: 'GPay',    emoji: 'G', packageParam: 'gpay'),
    _UpiApp(name: 'PhonePe', emoji: 'P', packageParam: 'phonepe'),
    _UpiApp(name: 'Paytm',   emoji: 'Py', packageParam: 'paytm'),
    _UpiApp(name: 'BHIM',    emoji: 'B', packageParam: null),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pay via', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
        const SizedBox(height: 10),
        Row(
          children: _apps.map((app) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onAppSelected(app),
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0E3), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(app.emoji, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF333333))),
                    ),
                    const SizedBox(height: 4),
                    Text(app.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Settle Numpad ─────────────────────────────────────────────────────────────

class _SettleNumpad extends StatelessWidget {
  const _SettleNumpad({required this.onKey});
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final keys = ['7','8','9','4','5','6','1','2','3','.','0','back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: keys.map((k) => _NumKey(label: k, onTap: () => onKey(k))).toList(),
    );
  }
}

class _NumKey extends StatefulWidget {
  const _NumKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFD8D8DB) : const Color(0xFFF0F0F2),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: widget.label == 'back'
            ? const Icon(Icons.backspace_outlined, size: 22, color: Color(0xFF555555))
            : Text(widget.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
      ),
    );
  }
}

// ── Swipe to Confirm ─────────────────────────────────────────────────────────

class _SwipeToConfirm extends StatefulWidget {
  const _SwipeToConfirm({required this.onConfirm, this.loading = false});
  final Future<void> Function() onConfirm;
  final bool loading;

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> {
  double _dragValue = 0.0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 60;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: _dragValue == 0 ? const Duration(milliseconds: 250) : Duration.zero,
                width: 60 + _dragValue,
                decoration: BoxDecoration(
                  color: AppColors.marigold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Center(
                child: widget.loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                    : Text(
                        _confirmed ? 'Opening UPI...' : 'Swipe to pay',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white54),
                      ),
              ),
              // Draggable thumb
              AnimatedPositioned(
                duration: _dragValue == 0 ? const Duration(milliseconds: 250) : Duration.zero,
                curve: Curves.easeOut,
                left: _dragValue,
                top: 0, bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (_confirmed || widget.loading) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(0, maxDrag);
                      if (_dragValue >= maxDrag) {
                        _confirmed = true;
                        widget.onConfirm();
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (!_confirmed) setState(() => _dragValue = 0);
                  },
                  child: Container(
                    width: 60,
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

// ── Confetti ──────────────────────────────────────────────────────────────────

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _random = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _particles = List.generate(24, (i) => _Particle(_random, i));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => SizedBox(
      width: 320, height: 220,
      child: CustomPaint(painter: _ConfettiPainter(_particles, _ctrl.value)),
    ),
  );
}

class _Particle {
  final double x;
  final double delay;
  final double speed;
  final Color color;
  final bool isRect;

  _Particle(math.Random r, int i)
      : x = r.nextDouble() * 260 - 130,
        delay = r.nextDouble() * 0.3,
        speed = 0.8 + r.nextDouble() * 0.8,
        isRect = i % 3 == 0,
        color = [AppColors.marigold, AppColors.rust, const Color(0xFF2F9E8F), const Color(0xFF7A86FF)][i % 4];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final pp = math.max(0.0, (progress - p.delay) / (1 - p.delay));
      if (pp <= 0 || pp >= 1) continue;
      final y = -20 + pp * 260 * p.speed;
      final x = size.width / 2 + p.x;
      final opacity = 1.0 - math.pow(pp, 1.5).toDouble();
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pp * math.pi * 5);
      if (p.isRect) {
        canvas.drawRect(const Rect.fromLTWH(-5, -3, 10, 6), paint);
      } else {
        canvas.drawCircle(Offset.zero, 4.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

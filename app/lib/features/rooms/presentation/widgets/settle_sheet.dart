import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/settle_repository.dart';
import '../../../../shared/widgets/avatar_widget.dart';

/// SettleSheet — light-mode "pay someone back" sheet (UI_UX_SPEC.md §4).
///
///   1. Edit amount (defaults to what you owe; can pay part of it)
///   2. Swipe to confirm → `settle-intent` validates server-side and records
///   3. UPI deep link built from the **server-validated** amount and the
///      payee's UPI ID from the server — never local numbers
///      (PRODUCT_LOGIC.md §5). "Copy UPI ID + amount" is always shown
///      alongside, because Safari on the iOS PWA can't reliably hand off
///      `upi://` links.
class SettleSheet extends ConsumerStatefulWidget {
  const SettleSheet({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.payeeId,
    required this.payeeName,
    required this.owedPaise,
  });

  final String roomId;
  final String roomName;
  final String payeeId;
  final String payeeName;
  final int owedPaise;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String roomName,
    required String payeeId,
    required String payeeName,
    required int owedPaise,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => SettleSheet(
        roomId: roomId,
        roomName: roomName,
        payeeId: payeeId,
        payeeName: payeeName,
        owedPaise: owedPaise,
      ),
    );
  }

  @override
  ConsumerState<SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends ConsumerState<SettleSheet> {
  late String _display;
  late int _maxPaise = widget.owedPaise;

  /// One op_id per sheet: a retry after a network blip reuses it, so the
  /// server can never record the same payment twice.
  late final String _opId = ref.read(settleRepositoryProvider).newOpId();

  bool _working = false;
  int _swipeAttempt = 0;
  String? _error;
  SettleIntent? _intent;

  @override
  void initState() {
    super.initState();
    _display = _paiseToInput(widget.owedPaise);
  }

  static String _paiseToInput(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  int get _amountPaise => parseRupeesToPaise(_display) ?? 0;

  void _onKey(String key) {
    setState(() {
      _error = null;
      if (key == 'back') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        }
        return;
      }
      if (key == '.' && _display.contains('.')) return;
      final next = _display + key;
      if (parseRupeesToPaise(next) != null || next.endsWith('.')) {
        _display = next;
      }
    });
  }

  Future<void> _confirm() async {
    final amount = _amountPaise;
    if (amount <= 0 || amount > _maxPaise) {
      setState(() {
        _error = amount <= 0
            ? 'Enter an amount'
            : 'That\'s more than you owe (${formatPaise(_maxPaise)})';
        _swipeAttempt++;
      });
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(settleRepositoryProvider)
          .settle(
            opId: _opId,
            roomId: widget.roomId,
            payerId: ref.read(currentUserIdProvider) ?? '',
            payeeId: widget.payeeId,
            amountPaise: amount,
          );
      if (!mounted) return;
      setState(() => _intent = intent);
      if (intent.upiId != null) await _launchUpi(intent);
    } on SettleError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (e.owedPaise != null) {
          _maxPaise = e.owedPaise!;
          _display = _paiseToInput(e.owedPaise!);
        }
        _swipeAttempt++;
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Uri _upiUri(SettleIntent intent) => Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': intent.upiId!,
      'pn': intent.payeeName,
      'am': (intent.validatedAmountPaise / 100).toStringAsFixed(2),
      'cu': 'INR',
      'tn': 'Splitsa: ${widget.roomName} settle',
      'tr': intent.opId,
    },
  );

  Future<void> _launchUpi(SettleIntent intent) async {
    try {
      await launchUrl(_upiUri(intent), mode: LaunchMode.externalApplication);
    } catch (_) {
      // No UPI app / PWA — the copy button below is the co-equal path.
    }
  }

  Future<void> _copyUpi(SettleIntent intent) async {
    final amount = (intent.validatedAmountPaise / 100).toStringAsFixed(2);
    await Clipboard.setData(ClipboardData(text: '${intent.upiId} · ₹$amount'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI ID + amount copied'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.fog,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.95, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: _intent != null ? _buildDone(_intent!) : _buildEntry(),
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
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SplitsaAvatar(
                  name: widget.payeeName,
                  tone: toneFor(widget.payeeId),
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pay ${widget.payeeName}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: groupRupeeInput(_display),
                        style: const TextStyle(fontSize: 48),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _error ??
                      'You owe ${formatPaise(_maxPaise)} · pay part or all of it',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _error != null
                        ? AppColors.rust
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _SettleNumpad(onKey: _onKey),
          const SizedBox(height: AppSpacing.xxl),
          _SwipeToConfirm(
            key: ValueKey(_swipeAttempt),
            loading: _working,
            onConfirm: _confirm,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We confirm the amount with the server before opening your UPI app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildDone(SettleIntent intent) {
    final hasUpi = intent.upiId != null;
    final isWeb = kIsWeb;
    return Padding(
      key: const ValueKey('done'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Stack(
            alignment: Alignment.center,
            children: [
              const _Confetti(),
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.marigold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.check, size: 36, color: AppColors.onBtn),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Settled! 🎉',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatPaise(intent.validatedAmountPaise, forceDecimals: true)} to ${intent.payeeName}',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (!hasUpi)
            Text(
              '${intent.payeeName} hasn\'t added a UPI ID yet — it\'s recorded here; pay them however you usually do.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            )
          else ...[
            _LightPill(
              label: isWeb ? 'Try opening UPI app' : 'Open UPI app again',
              filled: true,
              onTap: () => _launchUpi(intent),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LightPill(
              label: 'Copy UPI ID + amount',
              filled: false,
              onTap: () => _copyUpi(intent),
            ),
            if (isWeb) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'On iPhone, UPI links don\'t always open from the browser — copying always works.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Light-mode pill pair: exactly one filled, the other outlined (§1 rule).
class _LightPill extends StatelessWidget {
  const _LightPill({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
    );
    const size = Size(double.infinity, 52);
    return filled
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              minimumSize: size,
              shape: shape,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onBtn,
              ),
            ),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              shape: shape,
              side: BorderSide(color: AppColors.textPrimary),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          );
  }
}

// ── Settle Numpad ─────────────────────────────────────────────────────────────

class _SettleNumpad extends StatelessWidget {
  const _SettleNumpad({required this.onKey});
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final keys = [
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '.',
      '0',
      'back',
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: keys
          .map((k) => _NumKey(label: k, onTap: () => onKey(k)))
          .toList(),
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
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.fog : AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: widget.label == 'back'
            ? Icon(
                Icons.backspace_outlined,
                size: 22,
                color: AppColors.textSecondary,
              )
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}

// ── Swipe to Confirm ─────────────────────────────────────────────────────────

class _SwipeToConfirm extends StatefulWidget {
  const _SwipeToConfirm({
    super.key,
    required this.onConfirm,
    this.loading = false,
  });
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
            color: AppColors.fog,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: _dragValue == 0
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                width: 60 + _dragValue,
                decoration: BoxDecoration(
                  color: AppColors.marigoldTint,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Center(
                child: widget.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Text(
                        _confirmed ? 'Confirming…' : 'Swipe to pay',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              // Draggable thumb
              AnimatedPositioned(
                duration: _dragValue == 0
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                curve: Curves.easeOut,
                left: _dragValue,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (_confirmed || widget.loading) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(
                        0,
                        maxDrag,
                      );
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
                    decoration: BoxDecoration(
                      color: AppColors.btn,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.onBtn,
                      size: 18,
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

// ── Confetti ──────────────────────────────────────────────────────────────────

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _random = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _particles = List.generate(24, (i) => _Particle(_random, i));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => SizedBox(
      width: 320,
      height: 220,
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
      color = [
        AppColors.marigold,
        AppColors.rust,
        const Color(0xFF2F9E8F),
        const Color(0xFF7A86FF),
      ][i % 4];
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

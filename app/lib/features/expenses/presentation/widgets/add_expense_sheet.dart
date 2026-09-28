import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/split_amount.dart';
import 'expense_type_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.ctx});
  final ExpenseContext ctx;

  static Future<void> show(BuildContext context, ExpenseContext ctx) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => AddExpenseSheet(ctx: ctx),
    );
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  // ── Calculator state ──────────────────────────────────────────────────────
  String _display = '';        // what's shown in the display
  String _storedNum = '';      // left-hand operand
  String _pendingOp = '';      // +, −, ×, ÷
  bool _justApplied = false;   // suppress overwrite after = or operator

  int _mode = 0; // 0=Equally, 1=Unequally, 2=Percentage
  int _catIdx = 0;
  int? _subIdx;

  static const int _memberCount = 4; // TODO: wire from real room data

  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  final _categories = [
    {'name': 'Food',   'icon': Icons.restaurant,  'key': 'food',          'subs': ['Zomato', 'Swiggy', 'Dine-in', 'Groceries']},
    {'name': 'Travel', 'icon': Icons.flight,       'key': 'travel',        'subs': ['Flight', 'Train', 'Bus', 'Cab']},
    {'name': 'Home',   'icon': Icons.home,         'key': 'home',          'subs': ['Rent', 'Electricity', 'WiFi', 'Gas']},
    {'name': 'Fun',    'icon': Icons.celebration,  'key': 'entertainment', 'subs': ['Movies', 'Gaming', 'Events', 'Shopping']},
    {'name': 'Health', 'icon': Icons.favorite,     'key': 'health',        'subs': ['Medicine', 'Gym', 'Doctor', 'Other']},
  ];

  // ── Calculator logic ──────────────────────────────────────────────────────

  double get _currentValue => double.tryParse(_display) ?? 0;

  double _applyOp(double left, double right, String op) {
    return switch (op) {
      '+' => left + right,
      '−' => left - right,
      '×' => left * right,
      '÷' => right == 0 ? left : left / right,
      _   => right,
    };
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        } else if (_pendingOp.isNotEmpty) {
          // Un-commit the operator
          _display = _storedNum;
          _storedNum = '';
          _pendingOp = '';
        }
        _justApplied = false;
        return;
      }

      if (key == '=') {
        if (_pendingOp.isNotEmpty && _display.isNotEmpty) {
          final result = _applyOp(double.parse(_storedNum), _currentValue, _pendingOp);
          _display = _formatResult(result);
          _storedNum = '';
          _pendingOp = '';
          _justApplied = true;
        }
        return;
      }

      // Number or decimal
      if (key == '.') {
        if (_justApplied) { _display = '0.'; _justApplied = false; return; }
        if (_display.contains('.')) return;
        if (_display.isEmpty) _display = '0';
        _display += '.';
        return;
      }

      // Numeric digit
      if (_justApplied) { _display = key; _justApplied = false; return; }
      if (_display.length < 9) _display += key;
    });
  }

  void _onOperator(String op) {
    if (_display.isEmpty && _storedNum.isEmpty) return;
    setState(() {
      if (_storedNum.isNotEmpty && _display.isNotEmpty && _pendingOp.isNotEmpty) {
        // Chain: 3 + 4 × → evaluate 3+4 first
        final result = _applyOp(double.parse(_storedNum), _currentValue, _pendingOp);
        _storedNum = _formatResult(result);
        _display = '';
      } else if (_display.isNotEmpty) {
        _storedNum = _display;
        _display = '';
      }
      _pendingOp = op;
      _justApplied = false;
    });
  }

  String _formatResult(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String get _displayText {
    // Show expression in display bar, e.g. "230 + 70"
    if (_pendingOp.isNotEmpty) {
      return '${_storedNum.isNotEmpty ? _storedNum : ''} $_pendingOp ${_display.isNotEmpty ? _display : ''}';
    }
    return _display.isEmpty ? '0' : _display;
  }

  String get _resolvedAmountStr {
    if (_pendingOp.isNotEmpty && _storedNum.isNotEmpty && _display.isNotEmpty) {
      final r = _applyOp(double.parse(_storedNum), _currentValue, _pendingOp);
      return _formatResult(r);
    }
    return _display.isEmpty ? '0' : _display;
  }

  int get _totalPaise {
    final rupees = double.tryParse(_resolvedAmountStr) ?? 0;
    return (rupees * 100).round();
  }

  String _perPersonText() {
    if (_totalPaise == 0) return '';
    final splits = splitAmount(_totalPaise, _memberCount, 0); // payer = index 0
    final perPerson = splits.last; // show non-payer share
    return '${_memberCount} people · ₹${(perPerson / 100).toStringAsFixed(0)} each';
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = widget.ctx.type == ExpenseType.personal;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 6,
              decoration: BoxDecoration(color: const Color(0xFFD8D8DB), borderRadius: BorderRadius.circular(100)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Scrollable content ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Context chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isPersonal ? '👤 Personal expense' : '👥 Split expense',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Split mode tabs
                  if (!isPersonal) ...[
                    _SplitModeTabs(currentMode: _mode, onChanged: (m) => setState(() => _mode = m)),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Amount display
                  Center(
                    child: Column(
                      children: [
                        // Expression bar (shows "230 + 70")
                        if (_pendingOp.isNotEmpty)
                          Text(
                            _displayText,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFFAAAAAA)),
                          ),
                        RichText(
                          text: TextSpan(
                            text: '₹',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                            children: [
                              TextSpan(
                                text: _resolvedAmountStr == '0' ? '0' : _resolvedAmountStr,
                                style: const TextStyle(fontSize: 48),
                              ),
                            ],
                          ),
                        ),
                        if (!isPersonal && _totalPaise > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _perPersonText(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFFA0A0A5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Operator row ─────────────────────────────────────────
                  _OperatorRow(activeOp: _pendingOp, onTap: _onOperator),
                  const SizedBox(height: AppSpacing.md),

                  // ── Number pad ───────────────────────────────────────────
                  _NumberPad(onKey: _onKey, onEquals: () => _onKey('=')),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Category picker ──────────────────────────────────────
                  const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipRow(
                    items: _categories.map((c) => (
                      label: c['name'] as String,
                      icon: c['icon'] as IconData,
                    )).toList(),
                    selected: _catIdx,
                    onSelected: (i) => setState(() { _catIdx = i; _subIdx = null; }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SubChipRow(
                    items: (_categories[_catIdx]['subs'] as List<String>),
                    selected: _subIdx,
                    onSelected: (i) => setState(() => _subIdx = _subIdx == i ? null : i),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // ── Sticky Add Button ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
            child: FilledButton(
              onPressed: _totalPaise == 0 ? null : () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF111111).withValues(alpha: 0.25),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: Text(
                _totalPaise == 0 ? 'Add expense' : 'Add ₹${_currencyFormat.format(_totalPaise ~/ 100)}',
                style: AppTextStyles.button.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Operator Row ──────────────────────────────────────────────────────────────

class _OperatorRow extends StatelessWidget {
  const _OperatorRow({required this.activeOp, required this.onTap});
  final String activeOp;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const ops = ['+', '−', '×', '÷'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ops.map((op) {
        final active = activeOp == op;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(op),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF111111) : const Color(0xFFF0F0F2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                op,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF555555),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Number Pad ────────────────────────────────────────────────────────────────

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onKey, required this.onEquals});
  final ValueChanged<String> onKey;
  final VoidCallback onEquals;

  @override
  Widget build(BuildContext context) {
    final keys = ['7','8','9','4','5','6','1','2','3','.','0','back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: keys.map((k) {
        return _NumKey(
          label: k,
          onTap: () => onKey(k),
        );
      }).toList(),
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

// ── Split mode tabs ───────────────────────────────────────────────────────────

class _SplitModeTabs extends StatelessWidget {
  const _SplitModeTabs({required this.currentMode, required this.onChanged});
  final int currentMode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Equally', 'Unequally', 'Percentage'];
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final active = currentMode == e.key;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(e.key),
            child: Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(e.value,
                    style: AppTextStyles.bodySemibold.copyWith(
                      color: active ? const Color(0xFF111111) : const Color(0xFFA0A0A5),
                    ),
                  ),
                  if (active)
                    Positioned(
                      bottom: -13, left: 0, right: 0,
                      child: Container(height: 2, color: const Color(0xFF111111)),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items, required this.selected, required this.onSelected});
  final List<({String label, IconData icon})> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.asMap().entries.map((e) {
          final active = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF111111) : const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(e.value.icon, color: active ? Colors.white : const Color(0xFF555555), size: 15),
                    const SizedBox(width: 6),
                    Text(e.value.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF555555))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubChipRow extends StatelessWidget {
  const _SubChipRow({required this.items, required this.selected, required this.onSelected});
  final List<String> items;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.asMap().entries.map((e) {
          final active = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? Colors.black.withValues(alpha: 0.08) : const Color(0xFFF7F7F8),
                  border: Border.all(color: active ? const Color(0xFF111111) : Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? const Color(0xFF111111) : const Color(0xFF888888))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

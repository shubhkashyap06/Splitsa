import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/split_amount.dart';
import '../../../../data/local/database.dart';
import '../../../../data/local/local_streams.dart';
import '../../../../data/remote/session.dart';
import '../../../../data/repositories/expense_repository.dart';
import '../../../../shared/widgets/avatar_widget.dart';
import '../../../rooms/application/room_providers.dart';
import 'expense_type_sheet.dart';

/// Category chips. Home sub-chips map to the fixed-cost keys the logic
/// engine excludes from volatility (`SpendFeatureData.fixedCategories`) —
/// logging "Rent" as plain "home" would silently skew the persona.
const _categories =
    <({String name, IconData icon, String key, List<(String, String)> subs})>[
      (
        name: 'Food',
        icon: Icons.restaurant,
        key: 'food',
        subs: [
          ('Zomato', 'food'),
          ('Swiggy', 'food'),
          ('Dine-in', 'food'),
          ('Groceries', 'food'),
        ],
      ),
      (
        name: 'Travel',
        icon: Icons.flight,
        key: 'travel',
        subs: [
          ('Flight', 'travel'),
          ('Train', 'travel'),
          ('Bus', 'travel'),
          ('Cab', 'travel'),
        ],
      ),
      (
        name: 'Home',
        icon: Icons.home,
        key: 'home',
        subs: [
          ('Rent', 'rent'),
          ('Electricity', 'electricity'),
          ('WiFi', 'wifi'),
          ('Gas', 'gas'),
          ('Subscriptions', 'subscriptions'),
        ],
      ),
      (
        name: 'Fun',
        icon: Icons.celebration,
        key: 'entertainment',
        subs: [
          ('Movies', 'entertainment'),
          ('Gaming', 'entertainment'),
          ('Events', 'entertainment'),
          ('Shopping', 'shopping'),
        ],
      ),
      (
        name: 'Health',
        icon: Icons.favorite,
        key: 'health',
        subs: [('Medicine', 'health'), ('Gym', 'health'), ('Doctor', 'health')],
      ),
      (name: 'Other', icon: Icons.receipt_long, key: 'other', subs: []),
    ];

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key, required this.ctx});
  final ExpenseContext ctx;

  static Future<void> show(BuildContext context, ExpenseContext ctx) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => AddExpenseSheet(ctx: ctx),
    );
  }

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  // ── Calculator state ──────────────────────────────────────────────────────
  String _display = '';
  String _storedNum = '';
  String _pendingOp = '';
  bool _justApplied = false;

  SplitMode _mode = SplitMode.equal;
  int _catIdx = 0;
  int? _subIdx;
  String? _payerId;
  String? _error;
  bool _saving = false;

  final _description = TextEditingController();

  /// Per-member entries for unequal (rupees) / percentage modes.
  final Map<String, TextEditingController> _shareInputs = {};

  bool get _isPersonal => widget.ctx.type == ExpenseType.personal;

  @override
  void dispose() {
    _description.dispose();
    for (final c in _shareInputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _inputFor(String userId) =>
      _shareInputs.putIfAbsent(userId, TextEditingController.new);

  // ── Calculator logic ──────────────────────────────────────────────────────

  double get _currentValue => double.tryParse(_display) ?? 0;

  double _applyOp(double left, double right, String op) => switch (op) {
    '+' => left + right,
    '−' => left - right,
    '×' => left * right,
    '÷' => right == 0 ? left : left / right,
    _ => right,
  };

  void _onKey(String key) {
    setState(() {
      _error = null;
      if (key == 'back') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        } else if (_pendingOp.isNotEmpty) {
          _display = _storedNum;
          _storedNum = '';
          _pendingOp = '';
        }
        _justApplied = false;
        return;
      }
      if (key == '=') {
        if (_pendingOp.isNotEmpty && _display.isNotEmpty) {
          _display = _formatResult(
            _applyOp(double.parse(_storedNum), _currentValue, _pendingOp),
          );
          _storedNum = '';
          _pendingOp = '';
          _justApplied = true;
        }
        return;
      }
      if (key == '.') {
        if (_justApplied) {
          _display = '0.';
          _justApplied = false;
          return;
        }
        if (_display.contains('.')) return;
        if (_display.isEmpty) _display = '0';
        _display += '.';
        return;
      }
      if (_justApplied) {
        _display = key;
        _justApplied = false;
        return;
      }
      // Max 2 decimals, max 9 chars.
      final dot = _display.indexOf('.');
      if (dot >= 0 && _display.length - dot > 2) return;
      if (_display.length < 9) _display += key;
    });
  }

  void _onOperator(String op) {
    if (_display.isEmpty && _storedNum.isEmpty) return;
    setState(() {
      if (_storedNum.isNotEmpty &&
          _display.isNotEmpty &&
          _pendingOp.isNotEmpty) {
        _storedNum = _formatResult(
          _applyOp(double.parse(_storedNum), _currentValue, _pendingOp),
        );
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
    if (v < 0) v = 0; // an expense can't be negative
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String get _displayText {
    if (_pendingOp.isNotEmpty) {
      return '$_storedNum $_pendingOp ${_display.isNotEmpty ? _display : ''}';
    }
    return _display.isEmpty ? '0' : _display;
  }

  String get _resolvedAmountStr {
    if (_pendingOp.isNotEmpty && _storedNum.isNotEmpty && _display.isNotEmpty) {
      return _formatResult(
        _applyOp(double.parse(_storedNum), _currentValue, _pendingOp),
      );
    }
    if (_pendingOp.isNotEmpty && _storedNum.isNotEmpty) return _storedNum;
    return _display.isEmpty ? '0' : _display;
  }

  int get _totalPaise =>
      ((double.tryParse(_resolvedAmountStr) ?? 0) * 100).round();

  // ── Split computation ─────────────────────────────────────────────────────

  /// userId → paise, remainder on the payer (PRODUCT_LOGIC.md §1).
  /// Throws [ExpenseValidationError] with a friendly message when the
  /// entries can't add up.
  Map<String, int> _computeShares(List<String> members, String payerId) {
    final total = _totalPaise;
    final payerIndex = members.indexOf(payerId);
    if (payerIndex < 0) throw const ExpenseValidationError('Pick who paid');

    final List<int> shares;
    switch (_mode) {
      case SplitMode.equal:
        shares = splitAmount(total, members.length, payerIndex);
      case SplitMode.unequal:
        final amounts = [
          for (final m in members) parseRupeesToPaise(_inputFor(m).text) ?? 0,
        ];
        final allocated = amounts.fold<int>(0, (s, v) => s + v);
        if (allocated > total) {
          throw ExpenseValidationError(
            'Shares add up to ${formatPaise(allocated)} — more than ${formatPaise(total)}',
          );
        }
        shares = splitByAmounts(total, amounts, payerIndex);
      case SplitMode.percentage:
        final pcts = [
          for (final m in members)
            double.tryParse(_inputFor(m).text.trim()) ?? 0,
        ];
        final sum = pcts.fold<double>(0, (s, v) => s + v);
        if ((sum - 100).abs() > 0.01) {
          throw ExpenseValidationError(
            'Percentages add up to ${sum.toStringAsFixed(1)}%, not 100%',
          );
        }
        shares = splitByPercentage(total, pcts, payerIndex);
    }
    return {for (var i = 0; i < members.length; i++) members[i]: shares[i]};
  }

  String _perPersonText(int memberCount) {
    if (_totalPaise == 0 || memberCount == 0) return '';
    final perPerson = _totalPaise ~/ memberCount;
    return '$memberCount people · ${formatPaise(perPerson)} each';
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(List<String> members) async {
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    final cat = _categories[_catIdx];
    final sub = _subIdx == null ? null : cat.subs[_subIdx!];
    final category = sub?.$2 ?? cat.key;
    final description = _description.text.trim().isNotEmpty
        ? _description.text.trim()
        : (sub?.$1 ?? cat.name);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (_isPersonal) {
        await repo.addPersonalExpense(
          userId: me,
          description: description,
          amountPaise: _totalPaise,
          category: category,
          subCategory: sub?.$1,
        );
      } else {
        final payer = _payerId ?? me;
        await repo.addSharedExpense(
          roomId: widget.ctx.roomId!,
          paidBy: payer,
          description: description,
          amountPaise: _totalPaise,
          category: category,
          subCategory: sub?.$1,
          splitMode: _mode,
          shares: _computeShares(members, payer),
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added ${formatPaise(_totalPaise)} ✓'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on ExpenseValidationError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserIdProvider);
    final profiles =
        ref.watch(profilesByIdProvider).valueOrNull ??
        const <String, ProfilesTableData>{};
    final room = _isPersonal
        ? null
        : ref.watch(roomDetailProvider(widget.ctx.roomId!));
    final members = room?.memberIds ?? const <String>[];
    final payerId = _payerId ?? me;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.95,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPersonal
                              ? Icons.person_outline
                              : Icons.group_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPersonal
                              ? 'Personal expense'
                              : room?.room.name ?? 'Split expense',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_isPersonal) ...[
                    _SplitModeTabs(
                      currentMode: _mode.index,
                      onChanged: (m) => setState(() {
                        _mode = SplitMode.values[m];
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Center(
                    child: Column(
                      children: [
                        if (_pendingOp.isNotEmpty)
                          Text(
                            _displayText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
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
                                text: _resolvedAmountStr,
                                style: const TextStyle(fontSize: 48),
                              ),
                            ],
                          ),
                        ),
                        if (!_isPersonal &&
                            _totalPaise > 0 &&
                            _mode == SplitMode.equal)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _perPersonText(members.length),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _LightTextField(
                    controller: _description,
                    hint: 'What was it for? (optional)',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _OperatorRow(activeOp: _pendingOp, onTap: _onOperator),
                  const SizedBox(height: AppSpacing.md),
                  _NumberPad(onKey: _onKey, onEquals: () => _onKey('=')),
                  const SizedBox(height: AppSpacing.xxl),
                  const _LightLabel('Category'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipRow(
                    items: _categories
                        .map((c) => (label: c.name, icon: c.icon))
                        .toList(),
                    selected: _catIdx,
                    onSelected: (i) => setState(() {
                      _catIdx = i;
                      _subIdx = null;
                    }),
                  ),
                  if (_categories[_catIdx].subs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _SubChipRow(
                      items: _categories[_catIdx].subs
                          .map((s) => s.$1)
                          .toList(),
                      selected: _subIdx,
                      onSelected: (i) =>
                          setState(() => _subIdx = _subIdx == i ? null : i),
                    ),
                  ],
                  if (!_isPersonal && members.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const _LightLabel('Paid by'),
                    const SizedBox(height: AppSpacing.md),
                    _PayerGrid(
                      memberIds: members,
                      selectedId: payerId,
                      nameOf: (id) =>
                          id == me ? 'You' : (profiles[id]?.displayName ?? '?'),
                      onSelected: (id) => setState(() => _payerId = id),
                    ),
                    if (_mode != SplitMode.equal) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _LightLabel(
                        _mode == SplitMode.unequal
                            ? 'Each person\'s share (₹)'
                            : 'Each person\'s share (%)',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final id in members)
                        _ShareInputRow(
                          name: id == me
                              ? 'You'
                              : (profiles[id]?.displayName ?? '?'),
                          toneId: id,
                          controller: _inputFor(id),
                          suffix: _mode == SplitMode.unequal ? '₹' : '%',
                          onChanged: () => setState(() => _error = null),
                        ),
                      Text(
                        'Anything left over lands on whoever paid.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.rust),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: FilledButton(
              onPressed:
                  _totalPaise == 0 ||
                      _saving ||
                      (!_isPersonal && members.isEmpty)
                  ? null
                  : () => _save(members),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.btn,
                foregroundColor: AppColors.onBtn,
                disabledBackgroundColor: AppColors.fog,
                disabledForegroundColor: AppColors.textTertiary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                _totalPaise == 0
                    ? 'Add expense'
                    : 'Add ${formatPaise(_totalPaise)}',
                // No explicit colour: the button's enabled/disabled
                // foreground decides, so the disabled state stays legible.
                style: TextStyle(
                  fontSize: AppTextStyles.button.fontSize,
                  fontWeight: AppTextStyles.button.fontWeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Light-mode helpers ────────────────────────────────────────────────────────

class _LightLabel extends StatelessWidget {
  const _LightLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

class _LightTextField extends StatelessWidget {
  const _LightTextField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textCapitalization: TextCapitalization.sentences,
    style: TextStyle(
      fontSize: 15,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w500,
    ),
    cursorColor: AppColors.textPrimary,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

/// "Paid by" floating avatar grid (UI_UX_SPEC.md §3).
class _PayerGrid extends StatelessWidget {
  const _PayerGrid({
    required this.memberIds,
    required this.selectedId,
    required this.nameOf,
    required this.onSelected,
  });
  final List<String> memberIds;
  final String? selectedId;
  final String Function(String) nameOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        for (final id in memberIds)
          GestureDetector(
            onTap: () => onSelected(id),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  AnimatedScale(
                    scale: id == selectedId ? 1.08 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: SplitsaAvatar(
                      name: nameOf(id),
                      tone: toneFor(id),
                      size: 56,
                      ring: id == selectedId,
                      ringColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nameOf(id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: id == selectedId
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: id == selectedId
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShareInputRow extends StatelessWidget {
  const _ShareInputRow({
    required this.name,
    required this.toneId,
    required this.controller,
    required this.suffix,
    required this.onChanged,
  });
  final String name;
  final String toneId;
  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SplitsaAvatar(name: name, tone: toneFor(toneId), size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                suffixText: suffix,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? AppColors.textPrimary : AppColors.card,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                op,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.onBtn : AppColors.textSecondary,
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
      childAspectRatio: 2.0,
      children: keys.map((k) {
        return _NumKey(label: k, onTap: () => onKey(k));
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

// ── Split mode tabs ───────────────────────────────────────────────────────────

class _SplitModeTabs extends StatelessWidget {
  const _SplitModeTabs({required this.currentMode, required this.onChanged});
  final int currentMode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Equally', 'Unequally', 'Percentage'];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
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
                  Text(
                    e.value,
                    style: AppTextStyles.bodySemibold.copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (active)
                    Positioned(
                      bottom: -13,
                      left: 0,
                      right: 0,
                      child: Container(height: 2, color: AppColors.textPrimary),
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
  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onSelected,
  });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.textPrimary : AppColors.card,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(
                      e.value.icon,
                      color: active ? AppColors.onBtn : AppColors.textSecondary,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.value.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.onBtn
                            : AppColors.textSecondary,
                      ),
                    ),
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
  const _SubChipRow({
    required this.items,
    required this.selected,
    required this.onSelected,
  });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.textPrimary.withValues(alpha: 0.08)
                      : AppColors.card,
                  border: Border.all(
                    color: active ? AppColors.textPrimary : Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

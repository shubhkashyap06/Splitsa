import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import 'expense_type_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key, required this.ctx});
  final ExpenseContext ctx;

  static Future<void> show(BuildContext context, ExpenseContext ctx) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(ctx: ctx),
    );
  }

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  String _amount = '';
  int _mode = 0; // 0=Equally, 1=Unequally, 2=Percentage
  int _catIdx = 0;
  int? _subIdx;
  
  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  final _categories = [
    {'name': 'Food', 'icon': Icons.restaurant, 'subs': ['Zomato', 'Swiggy', 'Dine-in', 'Groceries']},
    {'name': 'Travel', 'icon': Icons.flight, 'subs': ['Flight', 'Train', 'Bus', 'Cab']},
    {'name': 'Home', 'icon': Icons.home, 'subs': ['Rent', 'Electricity', 'WiFi', 'Gas']},
    {'name': 'Fun', 'icon': Icons.celebration, 'subs': ['Movies', 'Gaming', 'Events', 'Shopping']},
  ];

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
    final isPersonal = widget.ctx.type == ExpenseType.personal;
    final displayAmount = _amount.isEmpty ? '0' : _amount;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Stack(
          children: [
            Container(
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
                  
                  // Context Chip
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        isPersonal ? 'Personal expense' : 'Split',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Split Modes
                  if (!isPersonal)
                    Container(
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                      child: Row(
                        children: ['Equally', 'Unequally', 'Percentage'].asMap().entries.map((e) {
                          final active = _mode == e.key;
                          return GestureDetector(
                            onTap: () => setState(() => _mode = e.key),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 24, bottom: 12),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Text(e.value, style: AppTextStyles.bodySemibold.copyWith(color: active ? const Color(0xFF111111) : const Color(0xFFA0A0A5))),
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
                    ),

                  // Amount Display
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '₹',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                            children: [
                              TextSpan(
                                text: displayAmount,
                                style: const TextStyle(fontSize: 44),
                              ),
                            ],
                          ),
                        ),
                        if (!isPersonal)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _mode == 0 ? '4 people · ₹${(_amount.isEmpty ? 0 : int.parse(_amount) / 4).toStringAsFixed(0)} each' : (_mode == 1 ? "total of everyone's share" : "enter a total, then split by %"),
                              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFA0A0A5), fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Numpad (for personal or equal split)
                  if (isPersonal || _mode == 0 || _mode == 2) ...[
                    _buildOperatorRow(),
                    const SizedBox(height: AppSpacing.md),
                    _buildNumberPad(),
                  ],

                  // Categories
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
                    child: Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: _categories.asMap().entries.map((e) {
                        final active = _catIdx == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() { _catIdx = e.key; _subIdx = null; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF111111) : const Color(0xFFF0F0F2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  Icon(e.value['icon'] as IconData, color: active ? Colors.white : const Color(0xFF555555), size: 16),
                                  const SizedBox(width: 8),
                                  Text(e.value['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF555555))),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Sub Categories
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: (_categories[_catIdx]['subs'] as List<String>).asMap().entries.map((e) {
                          final active = _subIdx == e.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _subIdx = active ? null : e.key),
                              child: Container(
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
                    ),
                  ),
                  
                  const SizedBox(height: 140), // Padding for the sticky button
                ],
              ),
            ),
            
            // Sticky Add Button
            Positioned(
              bottom: AppSpacing.xxl,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              child: FilledButton(
                onPressed: _amount.isEmpty ? null : () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF111111).withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text(
                  _amount.isEmpty ? 'Add expense' : 'Add ₹${_currencyFormat.format(int.parse(_amount))}',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
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

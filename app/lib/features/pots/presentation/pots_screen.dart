import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/progress_ring.dart';

class PotsScreen extends StatefulWidget {
  const PotsScreen({super.key});

  @override
  State<PotsScreen> createState() => _PotsScreenState();
}

class _PotsScreenState extends State<PotsScreen> {
  bool _fanned = false;
  
  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  final pots = [
    {
      'id': 'p1',
      'name': 'Goa Trip',
      'meta': '4 members',
      'target': 50000,
      'saved': 31000,
      'grad': [const Color(0xFFF2A73B), const Color(0xFFE8763C)],
    },
    {
      'id': 'p2',
      'name': 'PS5 Fund',
      'meta': '2 members',
      'target': 45000,
      'saved': 12000,
      'grad': [const Color(0xFF7A86FF), const Color(0xFF5A66FF)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cardH = 208.0;
    final peek = 104.0;
    final stackHeight = _fanned ? (cardH + 16) * pots.length : cardH + peek * (pots.length - 1) + 90;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
          children: [
            const Text('Savings', style: AppTextStyles.titleLarge),
            
            const SizedBox(height: AppSpacing.xxl),

            // Your Potli
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  ProgressRing(
                    progress: 62,
                    size: 116,
                    color: const Color(0xFF2F9E8F),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('62%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFF5F5F5))),
                        Text('there', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF8A8A8E))),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR POTLI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF8A8A8E))),
                        const SizedBox(height: 4),
                        const Text('Rainy Day Fund', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF5F5F5))),
                        const SizedBox(height: 8),
                        RichText(
                          text: const TextSpan(
                            text: '₹31,000 ',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2F9E8F)),
                            children: [
                              TextSpan(text: '/ ₹50,000', style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: Color(0xFF8A8A8E))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Group Pots Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Group Pots', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF5F5F5))),
                GestureDetector(
                  onTap: () => setState(() => _fanned = !_fanned),
                  child: Text(_fanned ? 'Stack' : 'Fan out', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8A8A8E))),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Stack
            SizedBox(
              height: stackHeight,
              child: Stack(
                children: [
                  ...pots.asMap().entries.map((e) {
                    final idx = e.key;
                    final pot = e.value;
                    final saved = pot['saved'] as int;
                    final target = pot['target'] as int;
                    final progress = (saved / target * 100).round();
                    
                    final top = _fanned ? idx * (cardH + 16) : idx * peek;
                    final scale = _fanned ? 1.0 : 1 - idx * 0.02;

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      top: top,
                      left: 0,
                      right: 0,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: scale, end: scale),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        builder: (context, val, child) {
                          return Transform.scale(
                            scale: val,
                            alignment: Alignment.topCenter,
                            child: child,
                          );
                        },
                        child: Container(
                          height: cardH,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: pot['grad'] as List<Color>,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned(
                                right: -32, top: -40,
                                child: Container(
                                  width: 128, height: 128,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                                ),
                              ),
                              Positioned(
                                right: 40, bottom: -48,
                                child: Container(
                                  width: 96, height: 96,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text((pot['name'] as String).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
                                        Text(pot['meta'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xxl),
                                    Text(
                                      _currencyFormat.format(saved),
                                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'of ${_currencyFormat.format(target)} · $progress%',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [Icons.add, Icons.edit, Icons.share].map((ic) {
                                        return Container(
                                          margin: const EdgeInsets.only(right: 10),
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                                          alignment: Alignment.center,
                                          child: Icon(ic, size: 17, color: Colors.white),
                                        );
                                      }).toList(),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  // New Pot
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    top: _fanned ? pots.length * (cardH + 16) : pots.length * peek,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: _fanned ? cardH : 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add, size: 22, color: Color(0xFF8A8A8E)),
                          SizedBox(height: 4),
                          Text('New Pot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8A8A8E))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

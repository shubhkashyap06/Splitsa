/// Onboarding carousel — 3 slides with soft parallax between illustration
/// and text, then a CTA to enter email.
///
/// Ported from docs/UI_UX_SPEC.md §4 "Onboarding + Phone/OTP Auth".
/// Auth method changed to email OTP (no SMS provider needed for dev).
/// Visual pattern is identical: n-slide carousel → entry field → OTP boxes.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_durations.dart';
import 'widgets/onboarding_illustration.dart';

class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  State<OnboardingCarouselScreen> createState() => _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      title: 'Split without the awkward chat',
      body: 'Add an expense, Splitsa divides it fairly — no more "who owes who" in a 3am group DM.',
      illustrationType: IllustrationType.split,
    ),
    _OnboardingSlide(
      title: 'Settle in one tap',
      body: 'Simplified balances. Pay via GPay, PhonePe, or Paytm — whatever works.',
      illustrationType: IllustrationType.settle,
    ),
    _OnboardingSlide(
      title: 'Your potli learns your patterns',
      body: 'Spots when you underspent, nudges you to save the difference — automatically.',
      illustrationType: IllustrationType.save,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.normal,
        curve: AppCurves.springy,
      );
    } else {
      context.pushNamed('auth-otp', queryParameters: {'email': ''});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.pushNamed('auth-otp', queryParameters: {'email': ''}),
                child: Text('Skip', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ),
            ),

            // ── Slides with parallax ───────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double offset = 0;
                      if (_pageController.hasClients && _pageController.position.haveDimensions) {
                        offset = (_pageController.page! - index).clamp(-1.0, 1.0);
                      }
                      // Parallax: illustration moves slower than text
                      return _SlideContent(
                        slide: _slides[index],
                        parallaxOffset: offset * 60,
                      );
                    },
                  );
                },
              ),
            ),

            // ── Page dots ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  return AnimatedContainer(
                    duration: AppDurations.fast,
                    curve: AppCurves.springy,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i ? AppColors.marigold : AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                  );
                }),
              ),
            ),

            // ── CTA button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxxl,
              ),
              child: _PrimaryButton(
                label: _currentPage < _slides.length - 1 ? 'Next' : 'Get started',
                onTap: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.illustrationType,
  });
  final String title;
  final String body;
  final IllustrationType illustrationType;
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide, required this.parallaxOffset});
  final _OnboardingSlide slide;
  final double parallaxOffset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration moves at a different rate than text (parallax)
          Transform.translate(
            offset: Offset(parallaxOffset * 0.6, 0),
            child: OnboardingIllustration(type: slide.illustrationType),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Text moves at full page speed (no transform needed — it's in the PageView)
          Transform.translate(
            offset: Offset(parallaxOffset * -0.15, 0),
            child: Column(
              children: [
                Text(
                  slide.title,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  slide.body,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: AppDurations.veryFast,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.marigold,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: AppColors.black),
          ),
        ),
      ),
    );
  }
}

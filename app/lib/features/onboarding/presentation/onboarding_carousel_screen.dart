/// Onboarding — three calm, animated slides, then email sign-in.
///
/// Each slide has its own looping illustration (onboarding_illustration.dart)
/// over slowly drifting colour glows; the illustration moves slower than the
/// text when swiping (parallax). Works in Day and Night.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/motion.dart';
import '../../../shared/widgets/sheets.dart';
import 'widgets/onboarding_illustration.dart';

class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _Slide {
  const _Slide(this.title, this.body, this.type);
  final String title;
  final String body;
  final IllustrationType type;
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      'Split without the awkward chat',
      'Add a bill, pick the room. Everyone sees their share instantly — no “who owes who” at 3am.',
      IllustrationType.split,
    ),
    _Slide(
      'Settle in one gentle swipe',
      'Splitsa works out the fewest payments, then hands off to GPay, PhonePe or Paytm.',
      IllustrationType.settle,
    ),
    _Slide(
      'Watch your potli grow',
      'Spend less this week? We’ll nudge the difference into your savings. Calm, never pushy.',
      IllustrationType.save,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToSignIn() =>
      context.pushNamed('auth-otp', queryParameters: {'email': ''});

  void _next() {
    if (_page < _slides.length - 1) {
      _pageController.nextPage(duration: Motion.slow, curve: Motion.settle);
    } else {
      _goToSignIn();
    }
  }

  List<Color> get _glows => switch (_page) {
    0 => [AppColors.glow, AppColors.lilacTint],
    1 => [AppColors.glow, AppColors.skyTint],
    _ => [AppColors.jadeTint, AppColors.glow],
  };

  @override
  Widget build(BuildContext context) {
    final glows = _glows;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Drifting glows that recolour per slide.
          AnimatedPositioned(
            duration: Motion.slow,
            curve: Motion.settle,
            top: -80,
            left: _page.isEven ? -90 : -40,
            child: _AnimatedGlow(color: glows[0], size: 300),
          ),
          AnimatedPositioned(
            duration: Motion.slow,
            curve: Motion.settle,
            top: 230,
            right: _page == 1 ? -60 : -110,
            child: _AnimatedGlow(color: glows[1], size: 260),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.jade,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sentiment_satisfied_rounded,
                          size: 18,
                          color: AppColors.background,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Splitsa', style: AppTextStyles.titleSmall),
                      const Spacer(),
                      TextButton(
                        onPressed: _goToSignIn,
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) => AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        var offset = 0.0;
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          offset = (_pageController.page! - index).clamp(
                            -1.0,
                            1.0,
                          );
                        }
                        return _SlideView(
                          slide: _slides[index],
                          parallax: offset * 60,
                        );
                      },
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final on = _page == i;
                    return AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.spring,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: on ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.textPrimary
                            : AppColors.textPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    child: PillButton(
                      key: ValueKey(_page == _slides.length - 1),
                      label: _page < _slides.length - 1
                          ? 'Continue'
                          : 'Let’s go',
                      onPressed: _next,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedGlow extends StatelessWidget {
  const _AnimatedGlow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: Motion.slow,
      builder: (ctx, c, _) => GlowBlob(
        color: c ?? color,
        size: size,
        opacity: AppColors.isNight ? 0.5 : 0.7,
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.parallax});
  final _Slide slide;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: Offset(parallax * 0.6, 0),
                child: OnboardingIllustration(type: slide.type),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(parallax * -0.15, 0),
            child: RiseIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontSize: 32,
                      height: 1.12,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    slide.body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

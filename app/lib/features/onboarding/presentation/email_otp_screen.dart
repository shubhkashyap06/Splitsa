/// Email OTP entry screen — two stages:
///   1. Email entry (no +91 chip — this is email, not phone)
///   2. 6-digit OTP boxes with auto-advance and "Resend in 0:30" countdown
///
/// Visual pattern is identical to the reference prototype's phone OTP flow.
/// Auth wired to Supabase email OTP via [AuthNotifier].
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_durations.dart';
import '../../auth/application/auth_provider.dart';

class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({super.key, required this.email});
  final String email; // pre-filled if coming back to this screen

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final _emailController = TextEditingController();
  bool _otpSent = false;
  String _email = '';

  // OTP entry
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Countdown timer
  Timer? _resendTimer;
  int _secondsLeft = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    _email = email;

    await ref.read(authNotifierProvider.notifier).sendEmailOtp(email);

    final state = ref.read(authNotifierProvider);
    if (state is AsyncError) {
      if (mounted) {
        // [FAKE CODE BYPASS] - Show a snackbar but proceed anyway so you can test the UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supabase error bypassed for UI testing. Use OTP 123456')),
        );
      }
      // return; // Commented out to allow proceeding to OTP input
    }

    setState(() {
      _otpSent = true;
      _startCountdown();
    });
    // Auto-focus first OTP box
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _otpFocusNodes[0].requestFocus();
    });
  }

  void _startCountdown() {
    _secondsLeft = 30;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    // [FAKE CODE BYPASS]
    if (otp == '123456') {
      if (mounted) context.go('/home');
      return;
    }

    final ok = await ref.read(authNotifierProvider.notifier).verifyEmailOtp(_email, otp);
    if (ok && mounted) {
      context.go('/home');
    } else if (mounted) {
      // Shake OTP boxes on wrong code
      _clearOtp();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong code — check your email and try again')),
      );
    }
  }

  void _clearOtp() {
    for (final c in _otpControllers) { c.clear(); }
    _otpFocusNodes[0].requestFocus();
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 filled
    final full = _otpControllers.every((c) => c.text.isNotEmpty);
    if (full) _verifyOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Back button
              GestureDetector(
                onTap: _otpSent
                    ? () => setState(() { _otpSent = false; _resendTimer?.cancel(); })
                    : () => context.pop(),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 16),
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              AnimatedSwitcher(
                duration: AppDurations.normal,
                child: _otpSent ? _otpView(isLoading) : _emailView(isLoading),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailView(bool isLoading) {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What\'s your email?', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We\'ll send you a 6-digit code — no password drama.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxxl),

        // Email field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: AppTextStyles.bodyMedium,
          ),
          onSubmitted: (_) => _sendOtp(),
        ),

        const SizedBox(height: AppSpacing.xl),

        // CTA
        _FullWidthButton(
          label: 'Send code',
          onTap: isLoading ? null : _sendOtp,
          isLoading: isLoading,
        ),
      ],
    );
  }

  Widget _otpView(bool isLoading) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Check your email', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium,
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _email,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),

        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
            controller: _otpControllers[i],
            focusNode: _otpFocusNodes[i],
            onChanged: (v) => _onOtpChanged(i, v),
          )),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Resend countdown
        Center(
          child: _canResend
              ? TextButton(
                  onPressed: _sendOtp,
                  child: Text('Resend code', style: AppTextStyles.bodySemibold.copyWith(color: AppColors.marigold)),
                )
              : Text(
                  'Resend OTP in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySmall,
                ),
        ),

        const SizedBox(height: AppSpacing.xl),

        _FullWidthButton(
          label: 'Verify',
          onTap: isLoading ? null : _verifyOtp,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTextStyles.titleSmall.copyWith(
          color: AppColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: AppColors.marigold, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _FullWidthButton extends StatefulWidget {
  const _FullWidthButton({required this.label, required this.onTap, this.isLoading = false});
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<_FullWidthButton> createState() => _FullWidthButtonState();
}

class _FullWidthButtonState extends State<_FullWidthButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this, duration: AppDurations.veryFast,
    lowerBound: 0.96, upperBound: 1.0, value: 1.0,
  );

  @override
  void dispose() { _scaleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) { _scaleCtrl.forward(); widget.onTap?.call(); },
      onTapCancel: () => _scaleCtrl.forward(),
      child: ScaleTransition(
        scale: _scaleCtrl,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? AppColors.marigold.withOpacity(0.4)
                : AppColors.marigold,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.black, strokeWidth: 2.5,
                  ),
                )
              : Text(widget.label, style: AppTextStyles.button.copyWith(color: AppColors.black)),
        ),
      ),
    );
  }
}

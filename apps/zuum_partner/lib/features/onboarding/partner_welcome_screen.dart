import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_design_system/design_system.dart';

import 'welcome_controller.dart';

/// Partner intro: three illustrated pages before sign-in. The last CTA persists
/// the flag and lets the router take the driver to login.
class PartnerWelcomeScreen extends ConsumerStatefulWidget {
  const PartnerWelcomeScreen({super.key});

  @override
  ConsumerState<PartnerWelcomeScreen> createState() =>
      _PartnerWelcomeScreenState();
}

class _PartnerWelcomeScreenState extends ConsumerState<PartnerWelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      illustration: 'onb_partner_dispatch',
      kannada: 'ನಿಮ್ಮ ದಿನ, ನಿಮ್ಮ ಆದಾಯ.',
      title: 'Your day, your earnings.',
      body:
          'Go online and receive ride and goods requests across Bengaluru. '
          'Every request shows your payout before you accept.',
      tint: ZColors.highlightTint,
    ),
    _Slide(
      illustration: 'onb_partner_earn',
      kannada: 'ಪ್ರತಿ ಟ್ರಿಪ್ಗೂ ಸ್ಪಷ್ಟ ಆದಾಯ.',
      title: 'Know your money first.',
      body:
          'A flat 20% commission, a live trip ledger, and weekly bank payouts. '
          'No surprises at settlement.',
      tint: ZColors.primaryTint,
    ),
    _Slide(
      illustration: 'onb_partner_fleet',
      kannada: 'ಒಂದೇ ಕಾನ್ಸೋಲ್‌ನಿಂದ ಫ್ಲೀಟ್ ನಿರ್ವಹಣೆ.',
      title: 'Lead a fleet, not just trips.',
      body:
          'Add vehicles, assign drivers, and track utilisation plus fleet '
          'earnings from one console.',
      tint: ZColors.highlightTint,
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() => ref.read(partnerWelcomeProvider.notifier).finish();

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _pages.nextPage(duration: ZMotion.base, curve: ZMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: ZColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.xxl,
                ZSpacing.md,
                ZSpacing.lg,
                ZSpacing.sm,
              ),
              child: Row(
                children: [
                  const ZBrandMark(),
                  const SizedBox(width: ZSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ZColors.highlight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'PARTNER',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.dark,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: ZTypography.bodyStrong.copyWith(
                        color: ZColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (_, index) => _SlideView(
                  slide: _slides[index],
                  active: index == _page,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.xxl,
                ZSpacing.sm,
                ZSpacing.xxl,
                ZSpacing.xxl,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: ZMotion.base,
                          curve: ZMotion.standard,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? ZColors.primary
                                : ZColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: ZSpacing.xl),
                  ZButton(
                    label: isLast ? 'Get started' : 'Continue',
                    icon: isLast ? Icons.bolt_rounded : Icons.arrow_forward,
                    onPressed: _next,
                  ),
                  const SizedBox(height: ZSpacing.sm),
                  Text(
                    isLast
                        ? 'Takes under 3 minutes to get verified.'
                        : 'Swipe to explore',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.textTertiary,
                      letterSpacing: 0.4,
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ZSpacing.md),
          AnimatedScale(
            scale: active ? 1 : 0.94,
            duration: ZMotion.slow,
            curve: ZMotion.standard,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: ZSpacing.xxl),
              decoration: BoxDecoration(
                color: slide.tint,
                borderRadius: BorderRadius.circular(ZRadii.xl),
              ),
              child: ZIllustration(slide.illustration, height: 200),
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text(
            slide.kannada,
            style: ZTypography.kannada(
              fontSize: 13,
              color: ZColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZSpacing.xs),
          Text(slide.title, style: ZTypography.display.copyWith(fontSize: 26)),
          const SizedBox(height: ZSpacing.sm),
          Text(
            slide.body,
            style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.illustration,
    required this.kannada,
    required this.title,
    required this.body,
    required this.tint,
  });

  final String illustration;
  final String kannada;
  final String title;
  final String body;
  final Color tint;
}

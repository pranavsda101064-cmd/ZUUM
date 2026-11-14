import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

/// Onboarding — Gemini spec §2b: brand pill + Skip top bar, illustration
/// cards, Kannada micro-headers, pill indicators, CTA that widens on slide 3.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      illustration: 'onb_auto',
      kannada: 'ಮೀಟರ್ ಹಾಕಿ, ಹೊರಡೋಣ',
      title: 'From Jayanagar filter coffee to Whitefield standups.',
      body:
          'Bikes, autos, hatchbacks, sedans, and SUVs with upfront, honest '
          'fares — no haggling at the signal.',
    ),
    _Slide(
      illustration: 'onb_goods',
      kannada: 'ಸಾಗಾಟ ಈಗ ಸುಲಭ',
      title: 'Move a tiffin box or a 1BHK house.',
      body:
          '2-wheeler parcels, 3W cargo, Tata Ace, and pickups dispatched on '
          'the same map in under 3 minutes.',
    ),
    _Slide(
      illustration: 'onb_metro',
      kannada: 'ನಂಬಿಕೆಯ ನಗರ ಸಂಚಾರ',
      title: "Built for Bengaluru's rhythm.",
      body:
          'Live radar tracking, verified city captains, and instant '
          'proof-of-delivery for every parcel.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(prefsStoreProvider).setOnboarded(true);
    if (!mounted) return;
    context.go('/auth/login');
  }

  void _next() {
    _pageController.nextPage(
      duration: ZMotion.base,
      curve: ZMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: ZColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand mini-pill + Skip.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpacing.xxl,
                vertical: ZSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ZColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ZUUM',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: ZTypography.bodyStrong
                          .copyWith(color: ZColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: ZSpacing.lg),
                        // Illustration card (rounded, bordered, no gradients).
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 180),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ZColors.background,
                              borderRadius: BorderRadius.circular(ZRadii.lg),
                              border: Border.all(color: ZColors.divider),
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/illustrations/${slide.illustration}.svg',
                              width: 240,
                            ),
                          ),
                        ),
                        const SizedBox(height: ZSpacing.lg),
                        Text(
                          slide.kannada,
                          style: ZTypography.kannada(
                            fontSize: 13,
                            color: ZColors.primary,
                          ),
                        ),
                        const SizedBox(height: ZSpacing.sm),
                        Text(slide.title, style: ZTypography.display),
                        const SizedBox(height: ZSpacing.sm),
                        Text(
                          slide.body,
                          style: ZTypography.body.copyWith(
                            color: ZColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: ZSpacing.lg),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom action row: pill indicators + CTA.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.xxl,
                ZSpacing.lg,
                ZSpacing.xxl,
                ZSpacing.xxl,
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: ZMotion.fast,
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? ZColors.primary
                                : ZColors.divider,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // CTA widens from 144dp to full width on the last slide.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    width: isLast ? 200 : 144,
                    child: ZButton(
                      label: isLast ? 'Get Moving' : 'Next',
                      onPressed: isLast ? _finish : _next,
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

class _Slide {
  const _Slide({
    required this.illustration,
    required this.kannada,
    required this.title,
    required this.body,
  });

  final String illustration;
  final String kannada;
  final String title;
  final String body;
}

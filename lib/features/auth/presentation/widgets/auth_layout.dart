import 'package:flutter/material.dart';

import '../../../../ui/ui.dart';

/// The responsive shell every auth screen sits in.
///
/// With artwork — wide (tablet, landscape, desktop): the artwork takes a
/// full-bleed panel beside the form. Narrow: it becomes a header band and
/// scrolls away the moment the patient starts typing.
///
/// Without artwork, there is no panel and no band: the form centres itself on
/// the canvas at every width. Sign-in uses this — the page is a credential
/// form, and an illustration on it is decoration the patient has to scroll
/// past to reach the thing they came for.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.child,
    this.heroHeadline,
    this.heroSupport,
    this.showArtwork = true,
  });

  final Widget child;
  final String? heroHeadline;
  final String? heroSupport;
  final bool showArtwork;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= Layout.splitBreakpoint;

        if (!showArtwork) {
          return _FormColumn(
            horizontalPadding: split ? Insets.xxxl : Insets.xl,
            child: child,
          );
        }

        if (split) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 47, child: _FormColumn(child: child)),
              Expanded(
                flex: 53,
                child: _HeroPanel(
                  headline: heroHeadline,
                  support: heroSupport,
                ),
              ),
            ],
          );
        }

        return _NarrowBody(child: child);
      },
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.child,
    this.horizontalPadding = Insets.xxxl,
  });

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: Insets.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Measured against the screen, not the laid-out box, so opening the
    // keyboard scrolls the header away instead of resizing it mid-tap.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final showHeader = screenHeight >= 480;
    final headerHeight = (screenHeight * 0.29).clamp(150.0, 300.0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) _HeroHeader(height: headerHeight),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Insets.xl,
              showHeader ? Insets.xs : Insets.xl,
              Insets.xl,
              Insets.xxl,
            ),
            child: SafeArea(
              top: !showHeader,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone header. The artwork's own ground is a cool near-white, so fading its
/// lower edge into the page makes it read as part of the screen rather than a
/// pasted-in rectangle.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.panel),
            // Framed to open just below the floating cross badge: a badge
            // sliced in half by the screen edge reads as an accident.
            const _HeroImage(alignment: Alignment(0, 0.28)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.canvas.withValues(alpha: 0),
                    c.canvas.withValues(alpha: 0),
                    c.canvas,
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({this.headline, this.support});

  final String? headline;
  final String? support;

  @override
  Widget build(BuildContext context) {
    final hasCopy = headline != null || support != null;

    return LayoutBuilder(
      builder: (context, constraints) => _panel(
        context,
        hasCopy: hasCopy,
        // A landscape phone gives the panel a third of the height a tablet
        // does, so the copy starts much higher up the image. The scrim has to
        // start higher with it or the headline lands on the illustration.
        short: constraints.maxHeight < 560,
      ),
    );
  }

  Widget _panel(
    BuildContext context, {
    required bool hasCopy,
    required bool short,
  }) {
    final c = context.colors;

    return ColoredBox(
      color: c.panel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroImage(alignment: Alignment(0, -0.04)),
          if (hasCopy)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.panel.withValues(alpha: 0),
                    c.panel.withValues(alpha: 0.82),
                    c.panel,
                  ],
                  stops: short
                      ? const [0.02, 0.4, 0.66]
                      : const [0.42, 0.72, 0.88],
                ),
              ),
            ),
          if (hasCopy)
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.xxxl,
                    Insets.xl,
                    Insets.xxxl,
                    Insets.xxxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (headline != null)
                          Text(
                            headline!,
                            textAlign: TextAlign.start,
                            style: context.text.headlineSmall,
                          ),
                        if (headline != null && support != null)
                          const SizedBox(height: Insets.sm),
                        if (support != null)
                          Text(
                            support!,
                            style: context.text.bodyMedium?.copyWith(
                              color: c.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final image = Image.asset(
      'assets/images/auth_hero.jpg',
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
    );

    return ExcludeSemantics(
      // The artwork has a near-white ground baked into the JPEG. Left alone in
      // dark mode it is a lit panel on an unlit page — the one bright rectangle
      // on a screen someone is looking at in bed. A wash of the canvas colour
      // pulls its whites down to meet the page; the illustration stays legible
      // and stops being a light source.
      child: c.isDark
          ? Stack(
              fit: StackFit.expand,
              children: [
                image,
                ColoredBox(color: c.canvas.withValues(alpha: 0.46)),
              ],
            )
          : image,
    );
  }
}

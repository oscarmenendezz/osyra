import 'dart:ui';

import 'package:flutter/material.dart';

class WatermarkBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final Alignment begin;
  final Alignment end;
  final String assetPath;
  final double opacity;

  const WatermarkBackground({
    super.key,
    required this.child,
    this.gradientColors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.assetPath = 'assets/branding/logo_osyra.png',
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoWidth = constraints.maxWidth * 0.58;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (gradientColors != null && gradientColors!.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: gradientColors!,
                  ),
                ),
              ),
            IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: 1.15,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
                      child: Image.asset(
                        assetPath,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

abstract final class FutureMintTokens {
  static const ink = Color(0xFF1B1B2A);
  static const cream = Color(0xFFF8F7FC);
  static const paper = Color(0xFFFFFFFF);
  static const mint = Color(0xFF6D5BD0);
  static const mintSoft = Color(0xFFE8E4FF);
  static const teal = Color(0xFF4B3FA7);
  static const tealDark = Color(0xFF342B7C);
  static const coral = Color(0xFFF96F61);
  static const coralSoft = Color(0xFFFFE0DC);
  static const sun = Color(0xFFF7C94C);
  static const sunSoft = Color(0xFFFFF0B8);
  static const lavender = Color(0xFFA58CE8);
  static const lavenderInk = Color(0xFF6953A7);
  static const lavenderSoft = Color(0xFFEAE4FC);
  // Neon accents
  static const neonPurple = Color(0xFF7B6BFF);
  static const neonGlow = Color(0xFF9B8CFF);
  static const periwinkle = Color(0xFF8EA4E7);
  static const periwinkleSoft = Color(0xFFE4E9FB);
  static const sky = Color(0xFF80C5EC);
  static const skyInk = Color(0xFF2B6587);
  static const skySoft = Color(0xFFE0F2FB);
  static const orange = Color(0xFFFFB34D);
  static const orangeSoft = Color(0xFFFFE4BC);
  static const pink = Color(0xFFE879C9);
  static const pinkSoft = Color(0xFFF8DDF0);
  static const coralInk = Color(0xFFB23A32);
  static const hairline = Color(0xFFDEDDEC);
  static const outline = Color(0xFF74728C);
  static const amber = Color(0xFFA85B00);
  static const canvas = cream;
  static const darkCanvas = Color(0xFF14131F);
  static const darkSurface = Color(0xFF1C1B2A);
  static const darkSurfaceRaised = Color(0xFF28263A);
  static const positive = Color(0xFF117A4B);
  static const danger = Color(0xFFB42318);

  static const radiusSmall = 12.0;
  static const radiusMedium = 20.0;
  static const radiusLarge = 28.0;
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;
  static const space7 = 48.0;
  static const space8 = 64.0;

  static const pageMaxWidth = 1200.0;
  static const contentNarrow = 760.0;
  static const contentReading = 840.0;
  static const contentCanvas = 980.0;
  static const railBreakpoint = 720.0;
  static const desktopCanvasBreakpoint = 900.0;
  static const wideBreakpoint = 1100.0;
  static const dashboardBentoWidth = 900.0;
  static const controlHeight = 48.0;

  static double pageGutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < railBreakpoint) return space4;
    if (width < wideBreakpoint) return space5;
    return space6;
  }

  static EdgeInsets cardPadding(BuildContext context) => EdgeInsets.all(
    MediaQuery.sizeOf(context).width < railBreakpoint ? space4 : space5,
  );
}

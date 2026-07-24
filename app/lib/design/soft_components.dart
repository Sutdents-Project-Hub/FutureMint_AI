import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Keeps focused content compact on smaller displays, while allowing primary
/// web destinations to use the complete area available beside the navigation
/// rail. Dialogs and authentication screens deliberately do not use this.
class ResponsivePageCanvas extends StatelessWidget {
  const ResponsivePageCanvas({
    super.key,
    required this.child,
    required this.compactMaxWidth,
  });

  final Widget child;
  final double compactMaxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useWebCanvas =
          constraints.maxWidth >= FutureMintTokens.desktopCanvasBreakpoint;

      if (useWebCanvas) {
        return SizedBox(width: constraints.maxWidth, child: child);
      }

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compactMaxWidth),
          child: child,
        ),
      );
    },
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.radius = FutureMintTokens.radiusMedium,
    this.borderColor,
    this.borderWidth = 0,
    this.elevated = false,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? scheme.outlineVariant,
                width: borderWidth,
              )
            : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  offset: const Offset(0, FutureMintTokens.space2),
                  blurRadius: FutureMintTokens.space5,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? FutureMintTokens.cardPadding(context),
        child: child,
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.kicker,
    required this.title,
    this.description,
    this.accent = FutureMintTokens.teal,
    this.trailing,
  });

  final String kicker;
  final String title;
  final String? description;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kicker,
          style: theme.textTheme.labelLarge?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: FutureMintTokens.space2),
        Text(title, style: theme.textTheme.headlineMedium),
        if (description != null) ...[
          const SizedBox(height: FutureMintTokens.space2),
          Text(
            description!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (trailing == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: FutureMintTokens.space4),
              trailing!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            const SizedBox(width: FutureMintTokens.space5),
            trailing!,
          ],
        );
      },
    );
  }
}

class NeonCard extends StatelessWidget {
  const NeonCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = FutureMintTokens.radiusMedium,
    this.borderWidth = 1.0,
    this.color,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double borderWidth;
  final Color? color;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? Theme.of(context).colorScheme.surface;
    final glow = dark ? FutureMintTokens.neonGlow : FutureMintTokens.neonPurple;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [base.withValues(alpha: .04), base.withValues(alpha: .02)]
              : [base, base.withValues(alpha: .98)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glow.withValues(alpha: .22),
          width: borderWidth,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: .12),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: glow.withValues(alpha: .06),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Padding(
        padding: padding ?? FutureMintTokens.cardPadding(context),
        child: child,
      ),
    );
  }
}

enum MoneyBuddyShape { blob, flower, spark }

class MoneyBuddy extends StatelessWidget {
  const MoneyBuddy({
    super.key,
    this.size = 92,
    this.color = FutureMintTokens.sun,
    this.shape = MoneyBuddyShape.blob,
    this.excludeSemantics = false,
  });

  final double size;
  final Color color;
  final MoneyBuddyShape shape;
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final art = Align(
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _MoneyBuddyPainter(
            color: color,
            shape: shape,
            faceColor: Theme.of(context).brightness == Brightness.dark
                ? FutureMintTokens.darkCanvas
                : FutureMintTokens.ink,
          ),
        ),
      ),
    );
    if (excludeSemantics) return ExcludeSemantics(child: art);
    return Semantics(label: 'FutureMint 金錢夥伴', image: true, child: art);
  }
}

class _MoneyBuddyPainter extends CustomPainter {
  const _MoneyBuddyPainter({
    required this.color,
    required this.shape,
    required this.faceColor,
  });

  final Color color;
  final MoneyBuddyShape shape;
  final Color faceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final highlight = Color.lerp(color, Colors.white, .38)!;
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.42),
        radius: 1.05,
        colors: [highlight, color],
      ).createShader(bounds);

    switch (shape) {
      case MoneyBuddyShape.blob:
        _drawBlob(canvas, size, fill);
      case MoneyBuddyShape.flower:
        _drawFlower(canvas, size, fill);
      case MoneyBuddyShape.spark:
        _drawSpark(canvas, size, fill);
    }
    _drawFace(canvas, size);
  }

  void _drawBlob(Canvas canvas, Size size, Paint fill) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .1)
      ..cubicTo(
        size.width * .8,
        size.height * .06,
        size.width * .94,
        size.height * .3,
        size.width * .88,
        size.height * .55,
      )
      ..cubicTo(
        size.width * .96,
        size.height * .8,
        size.width * .7,
        size.height * .96,
        size.width * .48,
        size.height * .88,
      )
      ..cubicTo(
        size.width * .2,
        size.height * .96,
        size.width * .05,
        size.height * .7,
        size.width * .13,
        size.height * .48,
      )
      ..cubicTo(
        size.width * .04,
        size.height * .22,
        size.width * .26,
        size.height * .08,
        size.width * .5,
        size.height * .1,
      )
      ..close();
    canvas.drawPath(path, fill);
  }

  void _drawFlower(Canvas canvas, Size size, Paint fill) {
    final center = size.center(Offset.zero);
    final petalRadius = size.width * .24;
    final distance = size.width * .2;
    for (var index = 0; index < 4; index++) {
      final angle = math.pi / 2 * index + math.pi / 4;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        petalRadius,
        fill,
      );
    }
    canvas.drawCircle(center, size.width * .28, fill);
  }

  void _drawSpark(Canvas canvas, Size size, Paint fill) {
    final center = size.center(Offset.zero);
    final path = Path();
    for (var index = 0; index < 16; index++) {
      final radius = index.isEven ? size.width * .46 : size.width * .27;
      final angle = -math.pi / 2 + index * math.pi / 8;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
  }

  void _drawFace(Canvas canvas, Size size) {
    final face = Paint()..color = faceColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .4, size.height * .47),
        width: size.width * .065,
        height: size.height * .09,
      ),
      face,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .6, size.height * .47),
        width: size.width * .065,
        height: size.height * .09,
      ),
      face,
    );
    final smile = Path()
      ..moveTo(size.width * .39, size.height * .61)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .7,
        size.width * .62,
        size.height * .6,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MoneyBuddyPainter oldDelegate) =>
      color != oldDelegate.color ||
      shape != oldDelegate.shape ||
      faceColor != oldDelegate.faceColor;
}

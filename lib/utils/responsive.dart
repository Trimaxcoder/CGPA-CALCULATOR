import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Width breakpoints used across SchoolLife.
class Breakpoints {
  /// Below this width: phone layout (bottom navigation).
  static const double medium = 600;

  /// At or above this width: desktop/web layout (extended sidebar).
  static const double expanded = 1024;

  /// Content never stretches wider than this on big screens.
  static const double contentMaxWidth = 1000;
}

enum ScreenSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  ScreenSize get screenSize {
    final w = screenWidth;
    if (w >= Breakpoints.expanded) return ScreenSize.expanded;
    if (w >= Breakpoints.medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;
}

/// Horizontal padding for a scrollable screen of the given available width.
/// Keeps normal padding on small screens and centers the content (capped at
/// [Breakpoints.contentMaxWidth]) on large ones, while the scrollbar stays at
/// the screen edge.
double responsiveSidePadding(double availableWidth, {double? maxWidth}) {
  final base = availableWidth >= 900
      ? 36.0
      : availableWidth >= 600
          ? 28.0
          : 20.0;
  final cap = maxWidth ?? Breakpoints.contentMaxWidth;
  return math.max(base, (availableWidth - cap) / 2);
}

/// Wrap a non-scrolling screen body with this to center it and cap its width.
class ContentConstrainer extends StatelessWidget {
  const ContentConstrainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Equal-width grid whose rows share the height of their tallest item.
/// Pass [columns] for a fixed count, or leave it null to fit as many columns
/// as [minItemWidth] allows.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.minItemWidth = 280,
    this.spacing = 14,
    this.runSpacing = 14,
  });

  final List<Widget> children;
  final int? columns;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns ??
            math.max(
              1,
              ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                  .floor(),
            );

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.skip(i).take(cols).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + cols < children.length) {
            rows.add(SizedBox(height: runSpacing));
          }
        }
        return Column(children: rows);
      },
    );
  }
}
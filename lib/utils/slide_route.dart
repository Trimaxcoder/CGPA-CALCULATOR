// lib/utils/slide_route.dart
//
// Page route that slides the new screen in from the right (and back out to
// the right on pop). Use it instead of MaterialPageRoute where you want the
// "WhatsApp style" slide, e.g. when a class card is tapped on a phone:
//
//   Navigator.of(context).push(
//     SlideRightRoute(builder: (_) => ClassScreen(room: room)),
//   );

import 'package:flutter/material.dart';

class SlideRightRoute<T> extends PageRouteBuilder<T> {
  SlideRightRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}

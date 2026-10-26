// lib/widgets/class_layout.dart
//
// Small shared pieces for the class space layout:
//  - the width at which the app switches to the WhatsApp-desktop style split view
//  - the slide-in route used on mobile when a chat room opens
//  - a notifier that tells the class list to reload

import 'package:flutter/material.dart';

/// At or above this width the class list and the chat sit side by side.
const double kClassSplitBreakpoint = 900;

/// Bump this to make the class list reload (used after leaving or archiving a
/// class, when the list needs to drop it).
final ValueNotifier<int> classListRefresh = ValueNotifier<int>(0);

/// A route that slides in from the right and slides back out on pop.
Route<T> classSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
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
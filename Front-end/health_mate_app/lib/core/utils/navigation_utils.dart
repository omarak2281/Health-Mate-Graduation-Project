import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 800),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

extension NavigationExtension on BuildContext {
  void pushFade(Widget page) {
    Navigator.of(this).push(FadePageRoute(page: page));
  }

  void pushReplacementFade(Widget page) {
    Navigator.of(this).pushReplacement(FadePageRoute(page: page));
  }
}

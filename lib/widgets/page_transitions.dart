import 'package:flutter/material.dart';

/// Custom page transitions for consistent navigation experience
class PageTransitions {
  /// Slide transition from right to left (default for forward navigation)
  static Route<T> slideRight<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  /// Slide transition from left to right (for back navigation)
  static Route<T> slideLeft<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  /// Fade transition
  static Route<T> fade<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  /// Scale transition
  static Route<T> scale<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
          ),
          child: child,
        );
      },
      transitionDuration: duration,
    );
  }

  /// Combined slide and fade transition
  static Route<T> slideFade<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        
        var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var slideAnimation = animation.drive(slideTween);
        
        var fadeTween = Tween(begin: 0.0, end: 1.0);
        var fadeAnimation = animation.drive(fadeTween);
        
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: duration,
    );
  }
}

/// Extension methods for easier navigation with transitions
extension NavigationTransitions on BuildContext {
  /// Navigate with slide transition
  Future<T?> pushSlideRight<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.of(this).push<T>(
      PageTransitions.slideRight(
        builder: (context) => page,
        settings: settings,
      ),
    );
  }

  /// Navigate with fade transition
  Future<T?> pushFade<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.of(this).push<T>(
      PageTransitions.fade(
        builder: (context) => page,
        settings: settings,
      ),
    );
  }

  /// Navigate with scale transition
  Future<T?> pushScale<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.of(this).push<T>(
      PageTransitions.scale(
        builder: (context) => page,
        settings: settings,
      ),
    );
  }

  /// Navigate with combined slide and fade transition
  Future<T?> pushSlideFade<T>(Widget page, {RouteSettings? settings}) {
    return Navigator.of(this).push<T>(
      PageTransitions.slideFade(
        builder: (context) => page,
        settings: settings,
      ),
    );
  }
}

/// Safe scrollable widget that prevents overflow issues
class SafeScrollable extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool primary;

  const SafeScrollable({
    super.key,
    required this.child,
    this.padding,
    this.physics,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(16),
        physics: physics ?? const BouncingScrollPhysics(),
        primary: primary,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 
                      MediaQuery.of(context).padding.top - 
                      MediaQuery.of(context).padding.bottom - 
                      (padding?.vertical ?? 32),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Safe column that ensures content fits within available space
class SafeColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final EdgeInsetsGeometry? padding;

  const SafeColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisAlignment: mainAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: [
          ...children,
          const SizedBox(height: 16), // Ensure space at bottom
        ],
      ),
    );
  }
}
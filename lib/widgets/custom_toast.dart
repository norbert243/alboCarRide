import 'package:flutter/material.dart';

class CustomToast {
  static void show({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    double borderRadius = 12.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 20.0,
      vertical: 16.0,
    ),
  }) {
    // Remove any existing toast
    _removeCurrentToast(context);

    // Create overlay entry
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewInsets.top + 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Insert overlay
    overlay.insert(overlayEntry);

    // Remove overlay after duration
    Future.delayed(duration, () {
      overlayEntry.remove();
    });

    // Store reference to current overlay entry
    _currentEntries[context] = overlayEntry;
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      duration: duration,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      duration: duration,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      duration: duration,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context: context,
      message: message,
      duration: duration,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
    );
  }

  // Store current overlay entries by context
  static final Map<BuildContext, OverlayEntry> _currentEntries = {};

  static void _removeCurrentToast(BuildContext context) {
    final currentEntry = _currentEntries[context];
    if (currentEntry != null) {
      try {
        currentEntry.remove();
      } catch (e) {
        // Overlay might already be removed, ignore the error
      }
      _currentEntries.remove(context);
    }
  }

  static void dismiss(BuildContext context) {
    _removeCurrentToast(context);
  }
}

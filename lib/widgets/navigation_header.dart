import 'package:flutter/material.dart';

/// Standardized navigation header for consistent navigation patterns
/// 
/// Provides consistent back/close button behavior across the application
class NavigationHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showCloseButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onClosePressed;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color foregroundColor;

  const NavigationHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showCloseButton = false,
    this.onBackPressed,
    this.onClosePressed,
    this.actions,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black87,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final List<Widget> leadingWidgets = [];

    // Add back button if enabled
    if (showBackButton) {
      leadingWidgets.add(
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
          color: foregroundColor,
        ),
      );
    }

    // Add close button if enabled (takes precedence over back button)
    if (showCloseButton) {
      leadingWidgets.clear(); // Clear any existing leading widgets
      leadingWidgets.add(
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClosePressed ?? () => Navigator.pop(context),
          color: foregroundColor,
        ),
      );
    }

    return AppBar(
      leading: leadingWidgets.isNotEmpty ? leadingWidgets.first : null,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
      ),
      backgroundColor: backgroundColor,
      elevation: 1,
      foregroundColor: foregroundColor,
      actions: actions,
    );
  }
}

/// Navigation header for modal dialogs with close button
class ModalNavigationHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClosePressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const ModalNavigationHeader({
    super.key,
    required this.title,
    this.onClosePressed,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClosePressed ?? () => Navigator.pop(context),
            color: foregroundColor,
          ),
        ],
      ),
    );
  }
}

/// Persistent bottom navigation bar for secondary screens
class PersistentNavigationBar extends StatelessWidget {
  final VoidCallback? onHomePressed;
  final VoidCallback? onBackPressed;
  final bool showHomeButton;
  final bool showBackButton;

  const PersistentNavigationBar({
    super.key,
    this.onHomePressed,
    this.onBackPressed,
    this.showHomeButton = true,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBackButton)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onBackPressed ?? () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                ),
              ),
            ),
          if (showBackButton && showHomeButton) const SizedBox(width: 16),
          if (showHomeButton)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onHomePressed ?? () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/role-selection',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.home),
                label: const Text('Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
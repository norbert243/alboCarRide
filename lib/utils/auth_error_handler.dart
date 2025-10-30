import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';

class AuthErrorHandler {
  /// Handle authentication errors with detailed user feedback
  static void handleAuthError(
    BuildContext context,
    dynamic error, {
    String? operation,
  }) {
    print('Auth Error [${operation ?? 'Unknown'}]: $error');

    String userMessage = 'An authentication error occurred. Please try again.';
    String debugMessage = error.toString();

    // Handle specific error types
    if (error is AuthException) {
      userMessage = _handleAuthException(error);
    } else if (error is PostgrestException) {
      userMessage = _handlePostgrestException(error);
    } else if (error is FormatException) {
      userMessage = 'Invalid data format. Please check your input.';
    } else if (error.toString().contains('timeout') ||
        error.toString().contains('Timeout')) {
      userMessage =
          'Request timeout. Please check your internet connection and try again.';
    } else if (error.toString().contains('socket') ||
        error.toString().contains('network')) {
      userMessage =
          'Network connection failed. Please check your internet connection.';
    } else if (error.toString().contains('invalid_client')) {
      userMessage =
          'Authentication configuration error. Please contact support.';
    }

    // Show error to user
    CustomToast.showError(context: context, message: userMessage);

    // Log detailed error for debugging
    _logErrorDetails(error, operation: operation);
  }

  /// Handle Supabase Auth exceptions
  static String _handleAuthException(AuthException error) {
    switch (error.message) {
      case 'Invalid login credentials':
        return 'Invalid phone number or verification code. Please check your details.';
      case 'User already registered':
        return 'This phone number is already registered. Please sign in instead.';
      case 'Email not confirmed':
        return 'Please verify your phone number before continuing.';
      case 'Token expired':
        return 'Your session has expired. Please sign in again.';
      case 'Invalid refresh token':
        return 'Session invalid. Please sign in again.';
      case 'User not found':
        return 'Account not found. Please check your phone number or create a new account.';
      case 'Too many requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      default:
        return 'Authentication error: ${error.message}';
    }
  }

  /// Handle Postgrest database exceptions
  static String _handlePostgrestException(PostgrestException error) {
    switch (error.code) {
      case '23505': // Unique violation
        return 'This information is already registered. Please use different details.';
      case '23503': // Foreign key violation
        return 'Database integrity error. Please contact support.';
      case '42501': // Insufficient privilege
        return 'Permission denied. Please contact support.';
      case '42P01': // Undefined table
        return 'System configuration error. Please contact support.';
      default:
        return 'Database error: ${error.message}';
    }
  }

  /// Log detailed error information for debugging
  static void _logErrorDetails(dynamic error, {String? operation}) {
    final timestamp = DateTime.now().toIso8601String();
    final errorType = error.runtimeType.toString();
    final stackTrace = error is Error
        ? error.stackTrace.toString()
        : 'No stack trace';

    print('''
=== AUTH ERROR LOG ===
Timestamp: $timestamp
Operation: ${operation ?? 'Unknown'}
Error Type: $errorType
Message: ${error.toString()}
Stack Trace: $stackTrace
=====================
''');
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverableError(dynamic error) {
    if (error is AuthException) {
      return ![
        'Invalid refresh token',
        'User not found',
        'Invalid client',
      ].contains(error.message);
    }

    if (error is PostgrestException) {
      return ![
        '23503', // Foreign key violation
        '42501', // Insufficient privilege
        '42P01', // Undefined table
      ].contains(error.code);
    }

    return error.toString().contains('network') ||
        error.toString().contains('timeout') ||
        error is FormatException;
  }

  /// Get retry suggestion based on error type
  static String getRetrySuggestion(dynamic error) {
    if (error.toString().contains('network')) {
      return 'Check your internet connection and try again.';
    } else if (error.toString().contains('timeout') ||
        error.toString().contains('Timeout')) {
      return 'The request took too long. Please try again.';
    } else if (error is AuthException && error.message == 'Too many requests') {
      return 'Wait a few minutes before trying again.';
    } else if (isRecoverableError(error)) {
      return 'Please check your information and try again.';
    } else {
      return 'Please contact support if the problem persists.';
    }
  }

  /// Show error dialog with retry option
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onRetry,
    VoidCallback? onCancel,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (onCancel != null)
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Handle error with automatic retry logic
  static Future<void> handleWithRetry(
    BuildContext context,
    Future<void> Function() operation,
    String operationName, {
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      try {
        await operation();
        return; // Success
      } catch (error) {
        attempts++;

        if (attempts > maxRetries || !isRecoverableError(error)) {
          // Final attempt failed or error is not recoverable
          handleAuthError(context, error, operation: operationName);
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(retryDelay * attempts);
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../constants.dart';

/// A helper class to handle dialogs that need to be shown over WebViews
/// This ensures the dialog can be interacted with properly
class DialogHelper {
  /// Shows a dialog that properly blocks WebView interactions
  /// 
  /// This method creates a dialog with an opaque barrier that ensures
  /// the WebView doesn't capture mouse events while the dialog is open.
  static Future<T?> showBlockingDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.7), // Use an opaque barrier to block WebView
      builder: builder,
    );
  }

  /// Shows a standard confirmation dialog with OK/Cancel buttons
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
  }) {
    return showBlockingDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText, style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Shows a loading dialog with a specified message
  static Future<void> showLoadingDialog({
    required BuildContext context,
    required String message,
  }) {
    return showBlockingDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// Shows an error dialog with an OK button
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showBlockingDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Shows a custom dialog with the proper barrier settings
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required Widget dialog,
    bool barrierDismissible = false,
  }) {
    return showBlockingDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => dialog,
    );
  }
} 
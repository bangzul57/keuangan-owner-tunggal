import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// Dialog konfirmasi dengan berbagai variasi
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final IconData? icon;
  final Color? iconColor;
  final ConfirmDialogType type;
  final bool showCancelButton; // RENAMED dari showCancel
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.icon,
    this.iconColor,
    this.type = ConfirmDialogType.confirm,
    this.showCancelButton = true, // RENAMED
    this.onConfirm,
    this.onCancel,
  });

  /// Tampilkan dialog konfirmasi
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    IconData? icon,
    Color? iconColor,
    ConfirmDialogType type = ConfirmDialogType.confirm,
    bool showCancelButton = true, // RENAMED
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        iconColor: iconColor,
        type: type,
        showCancelButton: showCancelButton, // RENAMED
      ),
    );

    return result ?? false;
  }

  /// Dialog konfirmasi hapus
  static Future<bool> showDelete({
    required BuildContext context,
    String? itemName,
    String? customMessage,
  }) {
    return show(
      context: context,
      title: AppStrings.confirmDelete,
      message: customMessage ??
          (itemName != null
              ? 'Yakin ingin menghapus "$itemName"?'
              : AppStrings.confirmDeleteDescription),
      confirmText: AppStrings.delete,
      type: ConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
  }

  /// Dialog konfirmasi batalkan - RENAMED dari showCancel
  static Future<bool> showCancelConfirm({
    required BuildContext context,
    String? customMessage,
  }) {
    return show(
      context: context,
      title: AppStrings.confirmCancel,
      message: customMessage ?? AppStrings.confirmCancelDescription,
      confirmText: AppStrings.yes,
      cancelText: AppStrings.no,
      type: ConfirmDialogType.warning,
      icon: Icons.warning_amber_outlined,
    );
  }

  /// Dialog informasi
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) async {
    await show(
      context: context,
      title: title,
      message: message,
      confirmText: buttonText ?? AppStrings.ok,
      type: ConfirmDialogType.info,
      icon: Icons.info_outline,
      showCancelButton: false,
    );
  }

  /// Dialog sukses
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) async {
    await show(
      context: context,
      title: title,
      message: message,
      confirmText: buttonText ?? AppStrings.ok,
      type: ConfirmDialogType.success,
      icon: Icons.check_circle_outline,
      showCancelButton: false,
    );
  }

  /// Dialog error
  static Future<void> showError({
    required BuildContext context,
    required String title,
    required String message,
    String? buttonText,
  }) async {
    await show(
      context: context,
      title: title,
      message: message,
      confirmText: buttonText ?? AppStrings.ok,
      type: ConfirmDialogType.danger,
      icon: Icons.error_outline,
      showCancelButton: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogColor = _getTypeColor();
    final dialogIcon = icon ?? _getTypeIcon();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: dialogColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Icon(
              dialogIcon,
              size: 48,
              color: dialogColor,
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                if (showCancelButton) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onCancel?.call();
                        Navigator.of(context).pop(false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(cancelText ?? AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onConfirm?.call();
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dialogColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(confirmText ?? AppStrings.confirm),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor() {
    if (iconColor != null) return iconColor!;

    switch (type) {
      case ConfirmDialogType.confirm:
        return AppColors.primary;
      case ConfirmDialogType.danger:
        return AppColors.error;
      case ConfirmDialogType.warning:
        return AppColors.warning;
      case ConfirmDialogType.success:
        return AppColors.success;
      case ConfirmDialogType.info:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case ConfirmDialogType.confirm:
        return Icons.help_outline;
      case ConfirmDialogType.danger:
        return Icons.error_outline;
      case ConfirmDialogType.warning:
        return Icons.warning_amber_outlined;
      case ConfirmDialogType.success:
        return Icons.check_circle_outline;
      case ConfirmDialogType.info:
        return Icons.info_outline;
    }
  }
}

/// Tipe dialog konfirmasi
enum ConfirmDialogType {
  confirm,
  danger,
  warning,
  success,
  info,
}

/// Dialog input dengan text field
class InputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? hintText;
  final String? confirmText;
  final String? cancelText;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialValue,
    this.hintText,
    this.confirmText,
    this.cancelText,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  /// Tampilkan input dialog
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String? confirmText,
    String? cancelText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _controller,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
              ),
              validator: widget.validator,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText ?? AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: Text(widget.confirmText ?? AppStrings.confirm),
        ),
      ],
    );
  }
}

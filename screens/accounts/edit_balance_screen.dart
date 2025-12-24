import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../widgets/money_input.dart';
import '../../widgets/primary_button.dart';

/// Screen untuk mengedit saldo akun (adjustment)
class EditBalanceScreen extends StatefulWidget {
  const EditBalanceScreen({super.key});

  @override
  State<EditBalanceScreen> createState() => _EditBalanceScreenState();
}

class _EditBalanceScreenState extends State<EditBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  final _notesController = TextEditingController();

  Account? _account;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Account && _account == null) {
      _account = args;
      _balanceController.text = Formatters.formatNumber(args.balance);
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _newBalance => Validators.parseAmount(_balanceController.text);

  double get _difference => _newBalance - (_account?.balance ?? 0);

  Future<void> _saveBalance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_account == null) return;

    // Tidak ada perubahan
    if (_difference == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada perubahan saldo')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<AccountProvider>();
    final success = await provider.updateBalance(_account!.id!, _newBalance);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal memperbarui saldo'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Saldo')),
        body: const Center(child: Text('Akun tidak ditemukan')),
      );
    }

    final account = _account!;
    final color = AppColors.getAccountTypeColor(account.type.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Saldo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Info
            _buildAccountInfo(theme, account, color),

            const SizedBox(height: 24),

            // Current Balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saldo Saat Ini',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    Formatters.formatCurrency(account.balance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // New Balance Input
            MoneyInput(
              controller: _balanceController,
              labelText: 'Saldo Baru',
              validator: (value) => Validators.amount(value, 'Saldo'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Difference
            _buildDifferenceCard(theme),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Penyesuaian (Opsional)',
                hintText: 'Alasan perubahan saldo',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 12),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perubahan saldo manual akan dicatat sebagai penyesuaian (adjustment) dalam jurnal.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            PrimaryButton(
              text: 'Simpan Perubahan',
              isLoading: _isLoading,
              onPressed: _saveBalance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(ThemeData theme, Account account, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getAccountIcon(account.type),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  account.type.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferenceCard(ThemeData theme) {
    final isPositive = _difference >= 0;

    if (_difference == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.horizontal_rule,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Tidak ada perubahan',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.add_circle : Icons.remove_circle,
                size: 16,
                color: isPositive ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                isPositive ? 'Penambahan' : 'Pengurangan',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          Text(
            '${isPositive ? '+' : ''}${Formatters.formatCurrency(_difference)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.wallet;
      case AccountType.digital:
        return Icons.smartphone;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.receivable:
        return Icons.receipt_long;
    }
  }
}

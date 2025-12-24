import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/money_input.dart';
import '../../widgets/primary_button.dart';

/// Form untuk prive (penarikan pribadi owner)
class PriveFormScreen extends StatefulWidget {
  const PriveFormScreen({super.key});

  @override
  State<PriveFormScreen> createState() => _PriveFormScreenState();
}

class _PriveFormScreenState extends State<PriveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    final accountProvider = context.read<AccountProvider>();
    _selectedAccount = accountProvider.cashAccount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _amount => Validators.parseAmount(_amountController.text);

  Future<void> _submitPrive() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun terlebih dahulu')),
      );
      return;
    }

    // Validasi saldo
    if (!_selectedAccount!.hasSufficientBalance(_amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saldo ${_selectedAccount!.name} tidak mencukupi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Konfirmasi dengan warning
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Konfirmasi Prive',
      message: _buildConfirmMessage(),
      confirmText: 'Proses',
      type: ConfirmDialogType.warning,
      icon: Icons.warning_amber,
    );

    if (!confirmed) return;

    final transactionProvider = context.read<TransactionProvider>();

    final success = await transactionProvider.processPrive(
      sourceAccountId: _selectedAccount!.id!,
      amount: _amount,
      description: 'Prive dari ${_selectedAccount!.name}',
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prive berhasil dicatat'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(transactionProvider.errorMessage ?? 'Prive gagal'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _buildConfirmMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Akun: ${_selectedAccount?.name}');
    buffer.writeln('Nominal: ${Formatters.formatCurrency(_amount)}');
    buffer.writeln('');
    buffer.writeln('⚠️ PERHATIAN:');
    buffer.writeln('Prive adalah penarikan untuk keperluan pribadi owner.');
    buffer.writeln('Transaksi ini akan mengurangi modal usaha.');
    buffer.writeln('');
    buffer.writeln('Saldo setelah prive:');
    buffer.writeln(Formatters.formatCurrency(_selectedAccount!.balance - _amount));

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.prive),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Warning Card
            _buildWarningCard(theme),

            const SizedBox(height: 24),

            // Account Selection
            Text(
              'Ambil dari Akun',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildAccountSelection(context, accountProvider),

            const SizedBox(height: 24),

            // Amount Input
            MoneyInput(
              controller: _amountController,
              labelText: 'Nominal Prive',
              validator: (value) {
                final error = Validators.positiveAmount(value, 'Nominal');
                if (error != null) return error;

                if (_selectedAccount != null) {
                  return Validators.sufficientBalance(
                    value,
                    _selectedAccount!.balance,
                    'Nominal',
                  );
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            // Summary
            if (_amount > 0 && _selectedAccount != null) _buildSummary(theme),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Keterangan (Opsional)',
                hintText: 'Contoh: Ambil untuk keperluan pribadi',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 32),

            // Submit Button
            PrimaryButton.danger(
              text: 'Proses Prive',
              icon: Icons.account_balance_wallet,
              isLoading: transactionProvider.isProcessing,
              onPressed: _submitPrive,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penarikan Pribadi (Prive)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prive adalah penarikan uang dari usaha untuk keperluan pribadi owner. '
                  'Transaksi ini akan mengurangi modal usaha dan dicatat sebagai pengeluaran.',
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

  Widget _buildAccountSelection(
    BuildContext context,
    AccountProvider provider,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: provider.assetAccounts.map((account) {
        final isSelected = _selectedAccount?.id == account.id;
        final color = AppColors.getAccountTypeColor(account.type.value);
        final canSelect = account.balance > 0;

        return Opacity(
          opacity: canSelect ? 1.0 : 0.5,
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: canSelect
                  ? () {
                      setState(() {
                        _selectedAccount = account;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
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
                            style: theme.textTheme.titleSmall?.copyWith(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatCurrency(account.balance),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!canSelect)
                          Text(
                            'Saldo kosong',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: color),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final balanceAfter = _selectedAccount!.balance - _amount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            theme,
            label: 'Saldo Saat Ini',
            value: Formatters.formatCurrency(_selectedAccount!.balance),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            theme,
            label: 'Nominal Prive',
            value: '- ${Formatters.formatCurrency(_amount)}',
            valueColor: AppColors.error,
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            theme,
            label: 'Saldo Setelah Prive',
            value: Formatters.formatCurrency(balanceAfter),
            isBold: true,
            valueColor: balanceAfter >= 0 ? null : AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
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

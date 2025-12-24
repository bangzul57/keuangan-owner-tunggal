import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/receivable.dart';
import '../../providers/receivable_provider.dart';
import '../../widgets/money_input.dart';
import '../../widgets/primary_button.dart';

/// Screen untuk menambah piutang manual
class AddReceivableScreen extends StatefulWidget {
  const AddReceivableScreen({super.key});

  @override
  State<AddReceivableScreen> createState() => _AddReceivableScreenState();
}

class _AddReceivableScreenState extends State<AddReceivableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _buyerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _buyerNameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _amount => Validators.parseAmount(_amountController.text);

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submitReceivable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ReceivableProvider>();

      final receivable = Receivable.create(
        buyerName: _buyerNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        totalAmount: _amount,
        dueDate: _dueDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      final id = await provider.addReceivable(receivable);

      if (id != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Piutang berhasil ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menambah piutang'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Piutang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tambahkan piutang manual untuk mencatat hutang yang belum tercatat dari transaksi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buyer Name
            TextFormField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Pembeli *',
                prefixIcon: Icon(Icons.person),
                hintText: 'Masukkan nama pembeli',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => Validators.required(value, 'Nama pembeli'),
            ),

            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon (Opsional)',
                prefixIcon: Icon(Icons.phone),
                hintText: 'Contoh: 08123456789',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => Validators.phoneNumber(value),
            ),

            const SizedBox(height: 16),

            // Amount
            MoneyInput(
              controller: _amountController,
              labelText: 'Nominal Piutang *',
              validator: (value) => Validators.positiveAmount(value, 'Nominal'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Due Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Jatuh Tempo'),
              subtitle: Text(
                _dueDate != null
                    ? Formatters.formatFullDate(_dueDate)
                    : 'Tidak ditentukan (opsional)',
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _selectDueDate,
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
                hintText: 'Tambahkan catatan jika perlu',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Preview Summary
            if (_amount > 0) _buildSummary(theme),

            const SizedBox(height: 32),

            // Submit Button
            PrimaryButton(
              text: 'Simpan Piutang',
              icon: Icons.save,
              isLoading: _isLoading,
              onPressed: _submitReceivable,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Divider(),
          _buildSummaryRow(
            theme,
            'Pembeli',
            _buyerNameController.text.trim().isNotEmpty
                ? _buyerNameController.text.trim()
                : '-',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            theme,
            'Nominal',
            Formatters.formatCurrency(_amount),
            isBold: true,
          ),
          if (_dueDate != null) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              theme,
              'Jatuh Tempo',
              Formatters.formatDate(_dueDate),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

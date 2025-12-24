import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/receivable.dart';
import '../../providers/receivable_provider.dart';
import '../../widgets/confirm_dialog.dart';
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

    // Konfirmasi
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Konfirmasi Piutang',
      message: _buildConfirmMessage(),
      confirmText: 'Simpan',
    );

    if (!confirmed) return;

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
  }

  String _buildConfirmMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Nama: ${_buyerNameController.text.trim()}');
    buffer.writeln('Nominal: ${Formatters.formatCurrency(_amount)}');
    if (_dueDate != null) {
      buffer.writeln('Jatuh Tempo: ${Formatters.formatDate(_dueDate)}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ReceivableProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Piutang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
                    : 'Tidak ditentukan',
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
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Submit
            PrimaryButton(
              text: 'Simpan Piutang',
              isLoading: provider.isProcessing,
              onPressed: _submitReceivable,
            ),
          ],
        ),
      ),
    );
  }
}

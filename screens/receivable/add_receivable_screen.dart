import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/account.dart';
import '../../models/journal_entry.dart';
import '../../models/receivable.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/receivable_provider.dart';

class AddReceivableScreen extends StatefulWidget {
  const AddReceivableScreen({super.key});

  @override
  State<AddReceivableScreen> createState() => _AddReceivableScreenState();
}

class _AddReceivableScreenState extends State<AddReceivableScreen> {
  // ============================================================
  // FORM STATE
  // ============================================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _sourceAccountId;
  bool _saving = false;

  int get _amount => int.tryParse(_amountController.text) ?? 0;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final assetAccounts = context
        .watch<AccountProvider>()
        .assetAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hutang Baru'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildNameField(),
              const SizedBox(height: 12),
              _buildAmountField(),
              const SizedBox(height: 12),
              _buildSourceAccountDropdown(assetAccounts),
              const SizedBox(height: 12),
              _buildNoteField(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Nama Pelanggan',
      ),
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Nominal Hutang',
      ),
      validator: (v) {
        final val = int.tryParse(v ?? '') ?? 0;
        if (val <= 0) return 'Nominal tidak valid';
        return null;
      },
    );
  }

  Widget _buildSourceAccountDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _sourceAccountId,
      decoration: const InputDecoration(
        labelText: 'Sumber Akun',
      ),
      items: accounts
          .map(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String,
              child: Text(a['name'] as String),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _sourceAccountId = v),
      validator: (v) => v == null ? 'Pilih sumber akun' : null,
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Catatan (opsional)',
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saving ? null : _handleSave,
      child: _saving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Simpan Hutang'),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await _saveReceivable();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveReceivable() async {
    final receivableProvider = context.read<ReceivableProvider>();
    final ledgerProvider = context.read<LedgerProvider>();
    final accountProvider = context.read<AccountProvider>();

    final receivableId = const Uuid().v4();
    final trxId = const Uuid().v4();

    // 1️⃣ buat akun piutang
    final receivableAccount = Account(
      id: receivableId,
      name: _nameController.text.trim(),
      type: 'asset',
      subType: 'receivable',
      isActive: true,
    );

    await receivableProvider.addReceivable(
      Receivable(
        id: receivableId,
        name: receivableAccount.name,
        amount: _amount,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    // 2️⃣ transaksi ledger
    final trx = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: 'Hutang ${receivableAccount.name}',
      category: 'receivable',
    );

    final entries = [
      // PIUTANG NAIK
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: receivableId,
        debit: _amount,
        credit: 0,
      ),
      // SUMBER AKUN TURUN
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _sourceAccountId!,
        debit: 0,
        credit: _amount,
      ),
    ];

    await ledgerProvider.runTransaction(
      transaction: trx,
      entries: entries,
    );

    await accountProvider.loadAssetAccounts();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

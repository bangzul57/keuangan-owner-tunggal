import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/account.dart';
import '../../models/journal_entry.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';

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
        .assetAccounts
        .where((a) => a['sub_type'] != 'receivable')
        .toList();

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
              _buildSourceDropdown(assetAccounts),
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
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nama wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Nominal Hutang',
      ),
      validator: (value) {
        final val = int.tryParse(value ?? '') ?? 0;
        if (val <= 0) return 'Nominal tidak valid';
        return null;
      },
    );
  }

  Widget _buildSourceDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _sourceAccountId,
      decoration: const InputDecoration(
        labelText: 'Sumber Hutang',
      ),
      items: accounts
          .map(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String,
              child: Text(a['name'] as String),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _sourceAccountId = value),
      validator: (value) => value == null ? 'Pilih akun sumber' : null,
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
    final accountProvider = context.read<AccountProvider>();
    final ledgerProvider = context.read<LedgerProvider>();

    // ============================
    // 1. BUAT AKUN PIUTANG
    // ============================

    final receivableId =
        'RCV_${_nameController.text.trim().toUpperCase().replaceAll(' ', '_')}';

    final receivableAccount = Account(
      id: receivableId,
      name: 'Piutang - ${_nameController.text.trim()}',
      type: 'asset',
      subType: 'receivable',
      isActive: true,
    );

    await accountProvider.addAccount(receivableAccount);

    // ============================
    // 2. TRANSAKSI + JURNAL
    // ============================

    final trxId = const Uuid().v4();

    final transaction = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: _noteController.text.isNotEmpty
          ? _noteController.text
          : 'Hutang ${_nameController.text.trim()}',
      category: 'receivable',
    );

    final entries = [
      // Piutang bertambah
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: receivableId,
        debit: _amount,
        credit: 0,
      ),
      // Sumber berkurang
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _sourceAccountId!,
        debit: 0,
        credit: _amount,
      ),
    ];

    await ledgerProvider.runTransaction(
      transaction: transaction,
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

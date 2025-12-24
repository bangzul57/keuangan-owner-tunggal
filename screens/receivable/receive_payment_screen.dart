import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/journal_entry.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';

class ReceivePaymentScreen extends StatefulWidget {
  final String receivableAccountId;
  final String receivableName;

  const ReceivePaymentScreen({
    super.key,
    required this.receivableAccountId,
    required this.receivableName,
  });

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  // ============================================================
  // FORM STATE
  // ============================================================

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _targetAccountId;
  bool _saving = false;

  int get _amount => int.tryParse(_amountController.text) ?? 0;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPER
  // ============================================================

  Map<String, dynamic> _getReceivableAccount(BuildContext context) {
    return context
        .read<AccountProvider>()
        .assetAccounts
        .firstWhere(
          (a) => a['id'] == widget.receivableAccountId,
          orElse: () => {},
        );
  }

  int _getCurrentBalance(BuildContext context) {
    final receivable = _getReceivableAccount(context);
    return receivable['balance'] as int? ?? 0;
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

    if (_getCurrentBalance(context) == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Terima Pembayaran'),
        ),
        body: const Center(
          child: Text(
            'Piutang sudah lunas',
            style: TextStyle(color: Colors.green),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terima Pembayaran'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildTargetAccountDropdown(assetAccounts),
              const SizedBox(height: 16),
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

  Widget _buildHeader() {
    final balance = _getCurrentBalance(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dari: ${widget.receivableName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Sisa Piutang: Rp $balance',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Nominal Diterima',
      ),
      validator: (value) {
        final val = int.tryParse(value ?? '') ?? 0;
        if (val <= 0) return 'Nominal tidak valid';
        return null;
      },
    );
  }

  Widget _buildTargetAccountDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _targetAccountId,
      decoration: const InputDecoration(
        labelText: 'Masuk ke Akun',
      ),
      items: accounts
          .map(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String?,
              child: Text(a['name'] as String? ?? ''),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _targetAccountId = value),
      validator: (value) => value == null ? 'Pilih akun penerima' : null,
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
          : const Text('Simpan Pembayaran'),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      _validatePayment();
      await _savePayment();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _validatePayment() {
    if (_targetAccountId == null) {
      throw Exception('Akun penerima belum dipilih');
    }

    final currentBalance = _getCurrentBalance(context);
    if (_amount > currentBalance) {
      throw Exception('Pembayaran melebihi sisa piutang (Rp $currentBalance)');
    }
  }

  Future<void> _savePayment() async {
    final ledgerProvider = context.read<LedgerProvider>();
    final accountProvider = context.read<AccountProvider>();

    final trxId = const Uuid().v4();

    final transaction = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: _buildDescription(),
      category: 'receivable_payment',
    );

    final entries = [
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _targetAccountId!,
        debit: _amount,
        credit: 0,
      ),
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: widget.receivableAccountId,
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

  String _buildDescription() {
    if (_noteController.text.isNotEmpty) {
      return _noteController.text;
    }
    return 'Pembayaran hutang ${widget.receivableName}';
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
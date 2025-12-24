import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/digital_transaction_mode.dart';
import '../../models/journal_entry.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';

class DigitalFormScreen extends StatefulWidget {
  const DigitalFormScreen({super.key});

  @override
  State<DigitalFormScreen> createState() => _DigitalFormScreenState();
}

class _DigitalFormScreenState extends State<DigitalFormScreen> {
  // ============================================================
  // FORM STATE
  // ============================================================

  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _adminController = TextEditingController(text: '2500');

  DigitalTransactionMode _mode = DigitalTransactionMode.sell;
  String? _kasAccountId;
  String? _digitalAccountId;
  bool _isSaving = false;

  int get _nominal => int.tryParse(_nominalController.text) ?? 0;
  int get _admin => int.tryParse(_adminController.text) ?? 0;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _nominalController.dispose();
    _adminController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().assetAccounts;

    final kasAccounts =
        accounts.where((a) => a['sub_type'] == 'cash').toList();
    final digitalAccounts =
        accounts.where((a) => a['sub_type'] == 'digital').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == DigitalTransactionMode.sell
              ? 'Jual Saldo'
              : 'Beli Saldo / Tarik Tunai',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildModeSelector(),
              const SizedBox(height: 12),
              _buildKasDropdown(kasAccounts),
              const SizedBox(height: 12),
              _buildDigitalDropdown(digitalAccounts),
              const SizedBox(height: 12),
              _buildNominalField(),
              const SizedBox(height: 12),
              _buildAdminField(),
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

  Widget _buildModeSelector() {
    return SegmentedButton<DigitalTransactionMode>(
      segments: const [
        ButtonSegment(
          value: DigitalTransactionMode.sell,
          label: Text('Jual'),
          icon: Icon(Icons.sell),
        ),
        ButtonSegment(
          value: DigitalTransactionMode.buy,
          label: Text('Beli/Tarik'),
          icon: Icon(Icons.shopping_cart),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (newSelection) {
        setState(() => _mode = newSelection.first);
      },
    );
  }

  Widget _buildKasDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _kasAccountId,
      decoration: const InputDecoration(labelText: 'Akun Kas'),
      items: accounts
          .map<DropdownMenuItem<String>>(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String,
              child: Text(a['name'] as String),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _kasAccountId = value),
      validator: (value) => value == null ? 'Wajib pilih' : null,
    );
  }

  Widget _buildDigitalDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _digitalAccountId,
      decoration: const InputDecoration(labelText: 'Akun Saldo Digital'),
      items: accounts
          .map<DropdownMenuItem<String>>(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String,
              child: Text(a['name'] as String),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _digitalAccountId = value),
      validator: (value) => value == null ? 'Wajib pilih' : null,
    );
  }

  Widget _buildNominalField() {
    return TextFormField(
      controller: _nominalController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Nominal Saldo'),
      validator: (value) =>
          (int.tryParse(value ?? '') ?? 0) <= 0 ? 'Tidak valid' : null,
    );
  }

  Widget _buildAdminField() {
    return TextFormField(
      controller: _adminController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Admin / Profit'),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _handleSave,
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Simpan Transaksi'),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_kasAccountId == null || _digitalAccountId == null) {
      _showError('Pilih akun Kas & Saldo Digital');
      return;
    }

    // ✅ Validasi admin tidak boleh >= nominal saat mode beli
    if (_mode == DigitalTransactionMode.buy && _admin >= _nominal) {
      _showError('Admin tidak boleh lebih besar atau sama dengan nominal');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _saveTransaction();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTransaction() async {
    final ledgerProvider = context.read<LedgerProvider>();
    final accountProvider = context.read<AccountProvider>();

    final trxId = const Uuid().v4();

    final transaction = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: _mode == DigitalTransactionMode.sell
          ? 'Jual saldo digital'
          : 'Beli saldo / tarik tunai',
      category: 'digital_sale',
    );

    final entries = _buildJournalEntries(trxId);

    await ledgerProvider.runTransaction(
      transaction: transaction,
      entries: entries,
    );

    if (!mounted) return;
    await accountProvider.loadAssetAccounts();
  }

  List<JournalEntry> _buildJournalEntries(String trxId) {
    if (_mode == DigitalTransactionMode.sell) {
      return _buildSellEntries(trxId);
    } else {
      return _buildBuyEntries(trxId);
    }
  }

  /// Jurnal untuk JUAL SALDO
  List<JournalEntry> _buildSellEntries(String trxId) {
    return [
      // Kas masuk
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _kasAccountId!,
        debit: _nominal + _admin,
        credit: 0,
      ),
      // Saldo keluar
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _digitalAccountId!,
        debit: 0,
        credit: _nominal,
      ),
      // Profit
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: 'PENDAPATAN',
        debit: 0,
        credit: _admin,
      ),
    ];
  }

  /// Jurnal untuk BELI SALDO / TARIK TUNAI
  List<JournalEntry> _buildBuyEntries(String trxId) {
    return [
      // Saldo masuk
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _digitalAccountId!,
        debit: _nominal,
        credit: 0,
      ),
      // Kas keluar (dikurangi admin)
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: _kasAccountId!,
        debit: 0,
        credit: _nominal - _admin,
      ),
      // Profit
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: 'PENDAPATAN',
        debit: 0,
        credit: _admin,
      ),
    ];
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
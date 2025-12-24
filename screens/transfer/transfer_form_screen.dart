import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';

class TransferFormScreen extends StatefulWidget {
  const TransferFormScreen({super.key});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  // ============================================================
  // FORM STATE
  // ============================================================

  final _formKey = GlobalKey<FormState>();
  final _transferController = TextEditingController();
  final _adminController = TextEditingController(text: '0');
  final _noteController = TextEditingController();

  String? _fromAccountId;
  String? _toAccountId;
  bool _saving = false;

  int get _transferAmount =>
      int.tryParse(_transferController.text.replaceAll('.', '')) ?? 0;

  int get _adminFee =>
      int.tryParse(_adminController.text.replaceAll('.', '')) ?? 0;

  int get _receivedAmount => _transferAmount - _adminFee;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _transferController.dispose();
    _adminController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().assetAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Antar Akun'),
      ),
      body: accounts.isEmpty
          ? const Center(child: Text('Belum ada akun'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildFromAccountDropdown(accounts),
                    const SizedBox(height: 12),
                    _buildToAccountDropdown(accounts),
                    const SizedBox(height: 12),
                    _buildTransferAmountField(),
                    const SizedBox(height: 12),
                    _buildAdminFeeField(),
                    const SizedBox(height: 8),
                    _buildReceivedInfo(),
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

  Widget _buildFromAccountDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _fromAccountId,
      decoration: const InputDecoration(labelText: 'Dari Akun'),
      items: accounts
          .map(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String?,
              child: Text(a['name'] as String? ?? ''),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _fromAccountId = value),
      validator: (value) => value == null ? 'Pilih akun sumber' : null,
    );
  }

  Widget _buildToAccountDropdown(List<Map<String, dynamic>> accounts) {
    return DropdownButtonFormField<String>(
      value: _toAccountId,
      decoration: const InputDecoration(labelText: 'Ke Akun'),
      items: accounts
          .map(
            (a) => DropdownMenuItem<String>(
              value: a['id'] as String?,
              child: Text(a['name'] as String? ?? ''),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _toAccountId = value),
      validator: (value) => value == null ? 'Pilih akun tujuan' : null,
    );
  }

  Widget _buildTransferAmountField() {
    return TextFormField(
      controller: _transferController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Nominal Transfer (keluar dari akun sumber)',
        hintText: 'Contoh: 300000',
      ),
      validator: (value) {
        final val = int.tryParse(value ?? '') ?? 0;
        if (val <= 0) return 'Nominal tidak valid';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildAdminFeeField() {
    return TextFormField(
      controller: _adminController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Biaya Admin (opsional)',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildReceivedInfo() {
    if (_transferAmount <= 0) {
      return const SizedBox.shrink();
    }

    if (_receivedAmount < 0) {
      return const Text(
        'Biaya admin melebihi nominal transfer',
        style: TextStyle(color: Colors.red),
      );
    }

    return Text(
      'Akun tujuan akan menerima: Rp $_receivedAmount',
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(labelText: 'Catatan'),
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
          : const Text('Simpan Transfer'),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == _toAccountId) {
      _showError('Akun sumber dan tujuan tidak boleh sama');
      return;
    }

    if (_adminFee < 0 || _adminFee > _transferAmount) {
      _showError('Biaya admin tidak valid');
      return;
    }

    setState(() => _saving = true);

    try {
      await _saveTransfer();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveTransfer() async {
    final ledgerProvider = context.read<LedgerProvider>();
    final accountProvider = context.read<AccountProvider>();

    await ledgerProvider.transferWithAdmin(
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      transferAmount: _transferAmount,
      adminFee: _adminFee,
      note: _noteController.text.trim(),
    );

    if (!mounted) return;
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
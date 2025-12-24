import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../providers/ledger_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/journal_entry.dart';
import '../../models/transaction_model.dart';

class PriveFormScreen extends StatefulWidget {
  const PriveFormScreen({super.key});

  @override
  State<PriveFormScreen> createState() => _PriveFormScreenState();
}

class _PriveFormScreenState extends State<PriveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _saving = false;

  int get amount => int.tryParse(_amountController.text) ?? 0;

  Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _saving = true);

  // ✅ Simpan reference provider SEBELUM await
  final ledgerProvider = context.read<LedgerProvider>();
  final accountProvider = context.read<AccountProvider>();

  final trxId = const Uuid().v4();

  final trx = TransactionModel(
    id: trxId,
    date: DateTime.now().millisecondsSinceEpoch,
    description:
        _noteController.text.isEmpty ? 'Prive' : _noteController.text,
    category: 'prive',
  );

  final entries = [
    // PRIVE masuk (equity)
    JournalEntry(
      id: const Uuid().v4(),
      transactionId: trxId,
      accountId: 'PRIVE',
      debit: amount,
      credit: 0,
    ),
    // KAS keluar
    JournalEntry(
      id: const Uuid().v4(),
      transactionId: trxId,
      accountId: 'KAS',
      debit: 0,
      credit: amount,
    ),
  ];

  try {
    await ledgerProvider.runTransaction(
      transaction: trx,
      entries: entries,
    );

    if (!mounted) return;

    // 🔥 refresh dashboard
    await accountProvider.loadAssetAccounts();

    if (!mounted) return;
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ambil Uang Usaha (Prive)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Nominal'),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) <= 0
                        ? 'Nominal tidak valid'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Simpan Prive'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

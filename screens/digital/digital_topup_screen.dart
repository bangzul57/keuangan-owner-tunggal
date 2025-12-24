import 'package:flutter/material.dart';
import '../../providers/ledger_provider.dart';
import '../../models/journal_entry.dart';
import '../../models/transaction_model.dart';
import 'package:uuid/uuid.dart';

class DigitalTopupScreen extends StatefulWidget {
  const DigitalTopupScreen({super.key});

  @override
  State<DigitalTopupScreen> createState() => _DigitalTopupScreenState();
}

class _DigitalTopupScreenState extends State<DigitalTopupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isSaving = false;

  int get amount => int.tryParse(_amountController.text) ?? 0;

  Future<void> _saveTopup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final trxId = Uuid().v4();

    final transaction = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: 'Isi saldo Dana (Modal)',
      category: 'digital_topup',
    );

    final entries = [
      // Dana bertambah
      JournalEntry(
        id: Uuid().v4(),
        transactionId: trxId,
        accountId: 'DANA',
        debit: amount,
        credit: 0,
      ),
      // Kas berkurang
      JournalEntry(
        id: Uuid().v4(),
        transactionId: trxId,
        accountId: 'KAS',
        debit: 0,
        credit: amount,
      ),
    ];

    try {
      await LedgerProvider().runTransaction(
        transaction: transaction,
        entries: entries,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Isi Saldo Dana')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Modal',
                ),
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) <= 0
                        ? 'Nominal tidak valid'
                        : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTopup,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Simpan Modal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

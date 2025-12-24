import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ledger_provider.dart';
import '../../providers/account_provider.dart';

class EditBalanceScreen extends StatefulWidget {
  final String accountId;
  final String accountName;
  final int currentBalance;

  const EditBalanceScreen({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.currentBalance,
  });

  @override
  State<EditBalanceScreen> createState() => _EditBalanceScreenState();
}

class _EditBalanceScreenState extends State<EditBalanceScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.currentBalance.toString());
  }

  Future<void> _save() async {
  final newBalance = int.tryParse(_controller.text) ?? 0;
  final diff = newBalance - widget.currentBalance;

  if (diff == 0) {
    Navigator.pop(context);
    return;
  }

  setState(() => _saving = true);

  // ✅ Simpan reference provider SEBELUM await
  final ledgerProvider = context.read<LedgerProvider>();
  final accountProvider = context.read<AccountProvider>();

  try {
    await ledgerProvider.adjustBalance(
      accountId: widget.accountId,
      amountDiff: diff,
      note: 'Penyesuaian saldo ${widget.accountName}',
    );

    if (!mounted) return;

    // 🔥 WAJIB reload akun setelah transaksi
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
      appBar: AppBar(title: const Text('Edit Saldo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo Baru',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import 'edit_balance_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;
  final String accountName;

  const AccountDetailScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountProvider>();

    final account = provider.assetAccounts.firstWhere(
      (a) => a['id'] == widget.accountId,
      orElse: () => {},
    );

    final balance = account.isNotEmpty
        ? (account['balance'] as int? ?? 0)
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saldo Saat Ini',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Rp $balance',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // ===== EDIT SALDO =====
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Saldo'),
              onPressed: () async {
                // ✅ Simpan reference provider SEBELUM await
                final accountProvider = context.read<AccountProvider>();

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditBalanceScreen(
                      accountId: widget.accountId,
                      accountName: widget.accountName,
                      currentBalance: balance,
                    ),
                  ),
                );

                if (!mounted) return;
                accountProvider.loadAssetAccounts();
              },
            ),

            const SizedBox(height: 12),

            // ===== HAPUS AKUN =====
            ElevatedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Hapus Akun'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => _confirmDelete(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // KONFIRMASI HAPUS AKUN
  // =========================
  Future<void> _confirmDelete() async {
    // ✅ Simpan reference provider SEBELUM await
    final accountProvider = context.read<AccountProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: const Text(
          'Akun akan dihapus dari daftar.\n'
          'Riwayat transaksi tetap disimpan.\n\n'
          'Akun hanya bisa dihapus jika saldo = 0.\n'
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await accountProvider.deactivateAccount(widget.accountId);

      if (!mounted) return;
      Navigator.pop(context); // kembali ke dashboard
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
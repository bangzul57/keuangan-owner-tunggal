import 'package:flutter/material.dart';

import '../../core/database/db_helper.dart';
import 'receive_payment_screen.dart';

class ReceivableDetailScreen extends StatelessWidget {
  final String accountId;
  final String accountName;

  const ReceivableDetailScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  Future<Map<String, dynamic>> _loadData() async {
    final db = await DBHelper.database;

    // ===== Ambil saldo piutang =====
    final balanceResult = await db.rawQuery('''
      SELECT COALESCE(SUM(debit - credit), 0) AS balance
      FROM journal_entries
      WHERE account_id = ?
    ''', [accountId]);

    final balance =
        (balanceResult.first['balance'] as int?) ?? 0;

    // ===== Ambil transaksi terkait =====
    final transactions = await db.rawQuery('''
      SELECT 
        t.id,
        t.date,
        t.description,
        t.category
      FROM transactions t
      JOIN journal_entries j
        ON j.transaction_id = t.id
      WHERE j.account_id = ?
      ORDER BY t.date DESC
    ''', [accountId]);

    return {
      'balance': balance,
      'transactions': transactions,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(accountName),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          final data = snapshot.data!;
          final balance = data['balance'] as int;
          final transactions =
              data['transactions'] as List<Map<String, dynamic>>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== SALDO =====
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sisa Hutang',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_rupiah(balance)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: balance > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ===== RIWAYAT =====
              Expanded(
                child: transactions.isEmpty
                    ? const Center(
                        child: Text('Belum ada transaksi'),
                      )
                    : ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final trx = transactions[index];
                          final date =
                              DateTime.fromMillisecondsSinceEpoch(
                            trx['date'] as int,
                          );

                          return ListTile(
                            title: Text(trx['description'] ?? '-'),
                            subtitle: Text(
                              '${_formatDate(date)} • ${trx['category']}',
                            ),
                            trailing:
                                const Icon(Icons.chevron_right),
                            onTap: () {
                              // nanti: ke TransactionDetailScreen
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // ===== TOMBOL TERIMA BAYAR (BELUM AKTIF) =====
      floatingActionButton: FloatingActionButton.extended(
  icon: const Icon(Icons.payments),
  label: const Text('Terima Pembayaran'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceivePaymentScreen(
          receivableAccountId: accountId,
          receivableName: accountName,
        ),
      ),
    );
  },
),

    );
  }

  String _formatDate(DateTime d) {
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
  }

  String _pad(int v) => v < 10 ? '0$v' : '$v';

  String _rupiah(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buffer.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }
    return buffer.toString();
  }
}

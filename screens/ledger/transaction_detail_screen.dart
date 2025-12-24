import 'package:flutter/material.dart';

import '../../core/database/db_helper.dart';

class TransactionDetailScreen extends StatelessWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  Future<Map<String, dynamic>> _loadDetail() async {
    final db = await DBHelper.database;

    final trxResult = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (trxResult.isEmpty) {
      throw Exception('Transaksi tidak ditemukan');
    }

    final trx = trxResult.first;

    final journal = await db.rawQuery('''
      SELECT 
        j.debit,
        j.credit,
        a.name AS account_name
      FROM journal_entries j
      JOIN accounts a ON a.id = j.account_id
      WHERE j.transaction_id = ?
      ORDER BY j.rowid ASC
    ''', [transactionId]);

    return {
      'transaction': trx,
      'journal': journal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data!;
          final trx = data['transaction'] as Map<String, dynamic>;
          final journal = data['journal'] as List<Map<String, dynamic>>;

          final date = DateTime.fromMillisecondsSinceEpoch(trx['date'] as int);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== HEADER =====
              Text(
                trx['description'] ?? '-',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(date)} • ${trx['category']}',
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // ===== JOURNAL =====
              for (final row in journal)
                _JournalRow(
                  accountName: row['account_name'] as String,
                  debit: row['debit'] as int,
                  credit: row['credit'] as int,
                ),
            ],
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
    return 'Rp ${buffer.toString()}';
  }
}

class _JournalRow extends StatelessWidget {
  final String accountName;
  final int debit;
  final int credit;

  const _JournalRow({
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = debit > 0;
    final amount = isDebit ? debit : credit;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(accountName),
      trailing: Text(
        (isDebit ? '+ ' : '- ') + _rupiah(amount),
        style: TextStyle(
          color: isDebit ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _rupiah(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buffer.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }
    return 'Rp ${buffer.toString()}';
  }
}
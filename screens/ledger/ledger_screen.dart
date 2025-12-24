import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/db_helper.dart';
import '../../providers/transaction_provider.dart';
import 'transaction_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  @override
  void initState() {
    super.initState();

    final trxProvider = context.read<TransactionProvider>();

    Future.microtask(() {
      trxProvider.loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final transactions = provider.transactions;

    if (transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: const Center(child: Text('Belum ada transaksi')),
      );
    }

    final grouped = _groupByDate(transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: ListView(
        children: grouped.entries.map((entry) {
          final dateKey = entry.key;
          final items = entry.value;

          return FutureBuilder<Map<String, int>>(
            future: _loadDailySummary(items),
            builder: (context, snapshot) {
              final masuk = snapshot.data?['masuk'] ?? 0;
              final keluar = snapshot.data?['keluar'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== HEADER TANGGAL =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: Colors.grey.shade200,
                    child: Text(
                      dateKey,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // ===== RINGKASAN HARIAN =====
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Masuk: ${_rupiah(masuk)}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Keluar: ${_rupiah(keluar)}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ===== LIST TRANSAKSI =====
                  ...items.map(
                    (trx) => ListTile(
                      title: Text(trx['description'] ?? '-'),
                      subtitle: Text(trx['category']),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transactionId: trx['id'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // GROUP TRANSAKSI BY TANGGAL
  // ==========================================
  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> list,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final trx in list) {
      final date =
          DateTime.fromMillisecondsSinceEpoch(trx['date'] as int);
      final key = _formatDate(date);

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(trx);
    }

    return grouped;
  }

  // ==========================================
  // LOAD RINGKASAN HARIAN LANGSUNG DARI DB
  // ==========================================
  Future<Map<String, int>> _loadDailySummary(
    List<Map<String, dynamic>> transactions,
  ) async {
    final db = await DBHelper.database;

    int masuk = 0;
    int keluar = 0;

    for (final trx in transactions) {
      final rows = await db.rawQuery('''
        SELECT debit, credit
        FROM journal_entries
        WHERE transaction_id = ?
      ''', [trx['id']]);

      for (final r in rows) {
        masuk += (r['debit'] as int);
        keluar += (r['credit'] as int);
      }
    }

    return {
      'masuk': masuk,
      'keluar': keluar,
    };
  }

  // ==========================================
  // FORMAT
  // ==========================================
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
    return 'Rp $buffer';
  }
}
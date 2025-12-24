import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/transaction_provider.dart';

class LedgerDetailScreen extends StatelessWidget {
  final String transactionId;
  final String description;

  const LedgerDetailScreen({
    super.key,
    required this.transactionId,
    required this.description,
  });

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: provider.loadJournalByTransaction(transactionId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final journals = snapshot.data!;

          return _buildContent(journals);
        },
      ),
    );
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildContent(List<Map<String, dynamic>> journals) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildJournalList(journals)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      description,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildJournalList(List<Map<String, dynamic>> journals) {
    return ListView.separated(
      itemCount: journals.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final journal = journals[index];
        return _buildJournalItem(journal);
      },
    );
  }

  Widget _buildJournalItem(Map<String, dynamic> journal) {
    final accountName = journal['account_name'] as String? ?? '';
    final debit = journal['debit'] as int? ?? 0;
    final credit = journal['credit'] as int? ?? 0;

    return ListTile(
      title: Text(accountName),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (debit > 0)
            Text(
              'Debit: $debit',
              style: const TextStyle(color: Colors.green),
            ),
          if (credit > 0)
            Text(
              'Credit: $credit',
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
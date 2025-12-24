import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import 'receivable_detail_screen.dart';

class ReceivableListScreen extends StatelessWidget {
  const ReceivableListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hutang Pelanggan'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: accountProvider.loadReceivables(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final receivables = snapshot.data!;

          if (receivables.isEmpty) {
            return const Center(
              child: Text(
                'Tidak ada hutang aktif',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            itemCount: receivables.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = receivables[index];
              final balance = r['balance'] as int? ?? 0;

              return ListTile(
                title: Text(r['name']),
                subtitle: Text('Sisa hutang: Rp $balance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceivableDetailScreen(
                        accountId: r['id'],
                        accountName: r['name'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
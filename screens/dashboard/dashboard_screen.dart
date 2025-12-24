import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../widgets/app_drawer.dart';
import '../accounts/account_detail_screen.dart';
import '../accounts/add_asset_account_screen.dart';
import '../digital/digital_form_screen.dart';
import '../transfer/transfer_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final accountProvider = context.read<AccountProvider>();
    final ledgerProvider = context.read<LedgerProvider>();

    await accountProvider.seedDefaultAccounts();
    if (!mounted) return;
    
    await accountProvider.loadAssetAccounts();
    if (!mounted) return;
    
    await ledgerProvider.loadDailySummary(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().assetAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildDailySummary(),
          const Divider(height: 1),
          Expanded(
            child: accounts.isEmpty
                ? _buildEmptyState(context)
                : _buildAccountList(accounts),
          ),
        ],
      ),
      floatingActionButton: _buildFabActions(context),
    );
  }

  Widget _buildDailySummary() {
    return Consumer<LedgerProvider>(
      builder: (context, ledger, child) {
        if (ledger.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Pendapatan : Rp ${ledger.dailyIncome}'),
              Text('Beban      : Rp ${ledger.dailyExpense}'),
              const SizedBox(height: 4),
              Text(
                'Laba        : Rp ${ledger.dailyProfit}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada akun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan akun Kas, Dana, Bank, dll\nuntuk mulai mencatat transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Tambah Akun'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddAssetAccountScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(List<Map<String, dynamic>> accounts) {
    return ListView.separated(
      itemCount: accounts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final acc = accounts[index];
        final balance = acc['balance'] as int? ?? 0;
        final name = acc['name'] as String? ?? 'Unknown';
        final id = acc['id'] as String? ?? '';

        return ListTile(
          title: Text(name),
          subtitle: Text('Saldo: Rp $balance'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(
                  accountId: id,
                  accountName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFabActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'addAccount',
          icon: const Icon(Icons.add),
          label: const Text('Tambah Akun'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddAssetAccountScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'digitalSale',
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Jual Saldo Digital'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DigitalFormScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'transfer',
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Transfer'),
          backgroundColor: Colors.blue,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TransferFormScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
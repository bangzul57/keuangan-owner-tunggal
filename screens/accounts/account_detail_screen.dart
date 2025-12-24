import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/account.dart';
import '../../models/journal_entry.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../widgets/confirm_dialog.dart';

/// Screen detail akun
class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({super.key});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  Account? _account;
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Account) {
      final ledgerProvider = context.read<LedgerProvider>();
      final entries = await ledgerProvider.loadEntriesForAccount(args.id!);

      if (mounted) {
        setState(() {
          _account = args;
          _entries = entries;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_account == null) return;

    final confirmed = await ConfirmDialog.showDelete(
      context: context,
      itemName: _account!.name,
    );

    if (!confirmed) return;

    final provider = context.read<AccountProvider>();
    final success = await provider.deleteAccount(_account!.id!);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Gagal menghapus akun'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Akun')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Akun')),
        body: const Center(child: Text('Akun tidak ditemukan')),
      );
    }

    final account = _account!;
    final accountColor = AppColors.getAccountTypeColor(account.type.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Akun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.pushNamed(
                context,
                AppRoutes.editBalance,
                arguments: account,
              );
              _loadData();
            },
          ),
          if (!account.isDefault)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteAccount();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Hapus Akun'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Header
            _buildAccountHeader(theme, account, accountColor),

            const SizedBox(height: 24),

            // Balance Summary
            _buildBalanceSummary(theme, account),

            const SizedBox(height: 24),

            // Account Info
            _buildAccountInfo(theme, account),

            const SizedBox(height: 24),

            // Recent Transactions
            _buildRecentTransactions(theme),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader(ThemeData theme, Account account, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getAccountIcon(account.type),
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            account.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            account.type.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Saldo Saat Ini',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          Text(
            Formatters.formatCurrency(account.balance),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(ThemeData theme, Account account) {
    final difference = account.balanceDifference;
    final isPositive = difference >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('Saldo Awal', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatCurrency(account.initialBalance),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: theme.dividerColor,
            ),
            Expanded(
              child: Column(
                children: [
                  Text('Perubahan', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: isPositive ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${Formatters.formatCurrency(difference)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(ThemeData theme, Account account) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Akun',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(theme, 'Tipe', account.type.label),
            if (account.description != null)
              _buildInfoRow(theme, 'Deskripsi', account.description!),
            _buildInfoRow(
              theme,
              'Dibuat',
              Formatters.formatDateTime(account.createdAt),
            ),
            _buildInfoRow(
              theme,
              'Diupdate',
              Formatters.formatDateTime(account.updatedAt),
            ),
            if (account.isDefault)
              _buildInfoRow(theme, 'Status', 'Akun Default'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(ThemeData theme) {
    final recentEntries = _entries.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aktivitas Terakhir',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_entries.length} transaksi',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(),
            if (recentEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada aktivitas',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentEntries.map((entry) => _buildEntryItem(theme, entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryItem(ThemeData theme, JournalEntry entry) {
    final isDebit = entry.isDebit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isDebit ? AppColors.success : AppColors.error,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ?? 'Transaksi #${entry.transactionId}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Formatters.formatRelativeDate(entry.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isDebit ? '+' : '-'}${Formatters.formatCurrency(entry.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDebit ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.wallet;
      case AccountType.digital:
        return Icons.smartphone;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.receivable:
        return Icons.receipt_long;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/account.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/balance_card.dart';

/// Dashboard utama aplikasi
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load semua data yang dibutuhkan
    final accountProvider = context.read<AccountProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final inventoryProvider = context.read<InventoryProvider>();

    await Future.wait([
      accountProvider.loadAccounts(),
      transactionProvider.loadTransactions(),
      inventoryProvider.loadItems(),
    ]);
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
              _showNotifications(context);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Balance Card
              _buildTotalBalanceCard(context),

              const SizedBox(height: 20),

              // Quick Actions
              _buildQuickActions(context, settingsProvider),

              const SizedBox(height: 24),

              // Account List
              _buildAccountSection(context),

              const SizedBox(height: 24),

              // Today's Summary
              _buildTodaySummary(context),

              const SizedBox(height: 24),

              // Recent Transactions
              _buildRecentTransactions(context),

              // Low Stock Alert (if retail enabled)
              if (settingsProvider.isRetailEnabled) ...[
                const SizedBox(height: 24),
                _buildLowStockAlert(context),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(context, settingsProvider),
    );
  }

  Widget _buildTotalBalanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final accountProvider = context.watch<AccountProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Saldo',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
                onPressed: () {
                  // TODO: Toggle visibility
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.formatCurrency(accountProvider.totalAssetBalance),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBalanceItem(
                context,
                'Kas',
                accountProvider.totalCashBalance,
                Icons.wallet,
              ),
              const SizedBox(width: 24),
              _buildBalanceItem(
                context,
                'Digital',
                accountProvider.totalDigitalBalance,
                Icons.smartphone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
  ) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  Formatters.formatCompact(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, SettingsProvider settings) {
    final actions = <_QuickAction>[];

    // Digital transaction
    if (settings.isDigitalEnabled) {
      actions.add(_QuickAction(
        icon: Icons.smartphone,
        label: 'Digital',
        color: AppColors.digitalAccount,
        onTap: () => Navigator.pushNamed(context, AppRoutes.digitalForm),
      ));
    }

    // Retail transaction
    if (settings.isRetailEnabled) {
      actions.add(_QuickAction(
        icon: Icons.store,
        label: 'Ritel',
        color: AppColors.success,
        onTap: () => Navigator.pushNamed(context, AppRoutes.retailForm),
      ));
    }

    // Transfer
    actions.add(_QuickAction(
      icon: Icons.swap_horiz,
      label: 'Transfer',
      color: AppColors.info,
      onTap: () => Navigator.pushNamed(context, AppRoutes.transferForm),
    ));

    // Receivable
    actions.add(_QuickAction(
      icon: Icons.receipt_long,
      label: 'Piutang',
      color: AppColors.warning,
      onTap: () => Navigator.pushNamed(context, AppRoutes.receivableList),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: actions.map((action) {
            return _buildQuickActionItem(context, action);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(BuildContext context, _QuickAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final theme = Theme.of(context);
    final accountProvider = context.watch<AccountProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Akun Saya',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.addAssetAccount);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (accountProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (accountProvider.assetAccounts.isEmpty)
          _buildEmptyState(
            context,
            icon: Icons.account_balance_wallet_outlined,
            message: 'Belum ada akun',
            action: 'Tambah Akun',
            onAction: () => Navigator.pushNamed(context, AppRoutes.addAssetAccount),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: accountProvider.assetAccounts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final account = accountProvider.assetAccounts[index];
                return _buildAccountCard(context, account);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final color = AppColors.getAccountTypeColor(account.type.value);

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.accountDetail,
          arguments: account,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getAccountIcon(account.type),
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.type.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(account.balance),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary(BuildContext context) {
    final theme = Theme.of(context);
    final transactionProvider = context.watch<TransactionProvider>();
    final todayTransactions = transactionProvider.todayTransactions;
    final todayProfit = transactionProvider.todayProfit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Hari Ini',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                context,
                icon: Icons.receipt_long,
                label: 'Transaksi',
                value: todayTransactions.length.toString(),
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryItem(
                context,
                icon: Icons.trending_up,
                label: 'Profit',
                value: Formatters.formatCurrency(todayProfit),
                color: todayProfit >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    final theme = Theme.of(context);
    final transactionProvider = context.watch<TransactionProvider>();
    final recentTransactions = transactionProvider.transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaksi Terakhir',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.ledger);
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactionProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (recentTransactions.isEmpty)
          _buildEmptyState(
            context,
            icon: Icons.receipt_long_outlined,
            message: 'Belum ada transaksi',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return _buildTransactionItem(context, transaction);
            },
          ),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isProfit = transaction.profit >= 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _getTransactionColor(transaction.transactionType).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _getTransactionIcon(transaction.transactionType),
          color: _getTransactionColor(transaction.transactionType),
          size: 20,
        ),
      ),
      title: Text(
        transaction.description ?? transaction.transactionType.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        Formatters.formatRelativeDate(transaction.transactionDate),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Formatters.formatCurrency(transaction.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (transaction.profit != 0)
            Text(
              '${isProfit ? '+' : ''}${Formatters.formatCurrency(transaction.profit)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isProfit ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.transactionDetail,
          arguments: transaction,
        );
      },
    );
  }

  Widget _buildLowStockAlert(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final lowStockItems = inventoryProvider.lowStockItems;

    if (lowStockItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Stok Menipis',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.inventoryList);
                },
                child: const Text('Lihat'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${lowStockItems.length} barang dengan stok rendah',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lowStockItems.take(3).map((item) {
              return Chip(
                label: Text(
                  '${item.name} (${item.stock})',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppColors.warning.withOpacity(0.2),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    String? action,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildFAB(BuildContext context, SettingsProvider settings) {
    return FloatingActionButton(
      onPressed: () {
        _showAddTransactionSheet(context, settings);
      },
      child: const Icon(Icons.add),
    );
  }

  void _showAddTransactionSheet(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Transaksi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
                if (settings.isDigitalEnabled)
                  _buildSheetItem(
                    context,
                    icon: Icons.smartphone,
                    title: 'Transaksi Digital',
                    subtitle: 'Beli/jual saldo e-wallet',
                    color: AppColors.digitalAccount,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.digitalForm);
                    },
                  ),
                if (settings.isRetailEnabled)
                  _buildSheetItem(
                    context,
                    icon: Icons.store,
                    title: 'Transaksi Ritel',
                    subtitle: 'Penjualan barang',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.retailForm);
                    },
                  ),
                _buildSheetItem(
                  context,
                  icon: Icons.swap_horiz,
                  title: 'Transfer',
                  subtitle: 'Transfer antar akun',
                  color: AppColors.info,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.transferForm);
                  },
                ),
                _buildSheetItem(
                  context,
                  icon: Icons.account_balance_wallet,
                  title: 'Prive',
                  subtitle: 'Penarikan pribadi',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.priveForm);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur notifikasi akan segera hadir'),
        behavior: SnackBarBehavior.floating,
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

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.digital:
        return Icons.smartphone;
      case TransactionType.retail:
        return Icons.store;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.prive:
        return Icons.account_balance_wallet;
      case TransactionType.adjustment:
        return Icons.tune;
      case TransactionType.receivablePayment:
        return Icons.payments;
    }
  }

  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.digital:
        return AppColors.digitalAccount;
      case TransactionType.retail:
        return AppColors.success;
      case TransactionType.transfer:
        return AppColors.info;
      case TransactionType.prive:
        return AppColors.error;
      case TransactionType.adjustment:
        return AppColors.warning;
      case TransactionType.receivablePayment:
        return AppColors.success;
    }
  }
}

/// Helper class untuk quick action
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/confirm_dialog.dart';

/// Screen daftar transaksi digital
class DigitalListScreen extends StatefulWidget {
  const DigitalListScreen({super.key});

  @override
  State<DigitalListScreen> createState() => _DigitalListScreenState();
}

class _DigitalListScreenState extends State<DigitalListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    var filtered = transactions
        .where((t) => t.transactionType == TransactionType.digital)
        .toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return (t.description?.toLowerCase().contains(query) ?? false) ||
            (t.buyerName?.toLowerCase().contains(query) ?? false) ||
            (t.transactionCode?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply date filter
    if (_dateFilter != null) {
      filtered = filtered.where((t) {
        final date = DateTime(
          t.transactionDate.year,
          t.transactionDate.month,
          t.transactionDate.day,
        );
        return !date.isBefore(_dateFilter!.start) &&
            !date.isAfter(_dateFilter!.end);
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFilter = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _dateFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactionProvider = context.watch<TransactionProvider>();

    final filteredTransactions = _filterTransactions(
      transactionProvider.transactions,
    );

    // Calculate summary
    final totalProfit = filteredTransactions.fold<double>(
      0,
      (sum, t) => sum + t.profit,
    );
    final totalAmount = filteredTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.digitalTransaction),
        actions: [
          if (_dateFilter != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Hapus Filter',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter Tanggal',
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Date Filter Chip
          if (_dateFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${Formatters.formatDate(_dateFilter!.start)} - ${Formatters.formatDate(_dateFilter!.end)}',
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _dateFilter = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Summary Card
          if (filteredTransactions.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Transaksi',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.formatCurrency(totalAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Profit',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.formatCurrency(totalProfit),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totalProfit >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Transaction List
          Expanded(
            child: transactionProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTransactions.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: () => transactionProvider.loadTransactions(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            return _buildTransactionCard(context, transaction);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.digitalForm);
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasFilter = _searchQuery.isNotEmpty || _dateFilter != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.search_off : Icons.smartphone_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Tidak ada transaksi yang cocok'
                  : 'Belum ada transaksi digital',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Coba ubah kata kunci atau filter'
                  : 'Mulai tambahkan transaksi digital pertama Anda',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Hapus Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel transaction) {
    final theme = Theme.of(context);
    final isProfit = transaction.profit >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.transactionDetail,
            arguments: transaction,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.digitalAccount.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getModeIcon(transaction.transactionMode?.value),
                      color: AppColors.digitalAccount,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.transactionMode?.label ?? 'Digital',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (transaction.buyerName != null)
                          Text(
                            transaction.buyerName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(transaction.amount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: isProfit ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            Formatters.formatCurrency(transaction.profit.abs()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isProfit ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Footer Row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDateTime(transaction.transactionDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (transaction.isCredit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HUTANG',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (transaction.adminFee > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Admin: ${Formatters.formatCurrency(transaction.adminFee)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(String? mode) {
    switch (mode) {
      case 'buy_balance':
        return Icons.shopping_cart;
      case 'sell_balance_deduct':
      case 'sell_balance_cash':
        return Icons.sell;
      case 'top_up':
        return Icons.add_card;
      default:
        return Icons.smartphone;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/app_drawer.dart';

/// Daftar transaksi digital
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
            (t.sourceAccountName?.toLowerCase().contains(query) ?? false) ||
            (t.destinationAccountName?.toLowerCase().contains(query) ?? false);
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
    final result = await showDateRangePicker(
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

    if (result != null) {
      setState(() {
        _dateFilter = result;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _dateFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.digitalTransaction),
        actions: [
          if (_dateFilter != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
              tooltip: 'Hapus Filter',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDateRange,
            tooltip: 'Filter Tanggal',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search & Filter Bar
          _buildSearchBar(),

          // Active Filters
          if (_dateFilter != null) _buildActiveFilters(),

          // Transaction List
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = _filterTransactions(provider.transactions);

                if (transactions.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: _buildTransactionList(transactions),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.digitalForm),
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
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
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          if (_dateFilter != null)
            Chip(
              label: Text(
                '${Formatters.formatDate(_dateFilter!.start)} - ${Formatters.formatDate(_dateFilter!.end)}',
                style: const TextStyle(fontSize: 12),
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                setState(() => _dateFilter = null);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smartphone_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _dateFilter != null
                ? 'Tidak ada transaksi yang cocok'
                : AppStrings.noTransactions,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _dateFilter != null
                ? 'Coba ubah kata kunci atau filter'
                : 'Mulai dengan membuat transaksi digital pertama',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty && _dateFilter == null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.digitalForm),
              icon: const Icon(Icons.add),
              label: const Text('Buat Transaksi'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions) {
    // Group by date
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final transaction in transactions) {
      final date = DateTime(
        transaction.transactionDate.year,
        transaction.transactionDate.month,
        transaction.transactionDate.day,
      );
      grouped.putIfAbsent(date, () => []).add(transaction);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayTransactions = grouped[date]!;
        final dayProfit = dayTransactions.fold<double>(
          0,
          (sum, t) => sum + t.profit,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatRelativeDate(date),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Profit: ${Formatters.formatCurrency(dayProfit)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dayProfit >= 0 ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),

            // Transactions
            ...dayTransactions.map((t) => _buildTransactionItem(t)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.transactionMode?.isBuyMode ?? false;
    final color = isIncome ? AppColors.expense : AppColors.income;

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.transactionDetail,
        arguments: transaction,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.transactionMode?.label ?? 'Transaksi Digital',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (transaction.buyerName != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          transaction.buyerName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        Formatters.formatTime(transaction.transactionDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.formatCurrency(transaction.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (transaction.profit != 0)
                  Text(
                    '+${Formatters.formatCurrency(transaction.profit)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),

            // Credit indicator
            if (transaction.isCredit) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Hutang',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/transaction_provider.dart';

/// Screen daftar transaksi ritel
class RetailListScreen extends StatefulWidget {
  const RetailListScreen({super.key});

  @override
  State<RetailListScreen> createState() => _RetailListScreenState();
}

class _RetailListScreenState extends State<RetailListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    var filtered = transactions
        .where((t) => t.transactionType == TransactionType.retail)
        .toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return (t.description?.toLowerCase().contains(query) ?? false) ||
            (t.buyerName?.toLowerCase().contains(query) ?? false) ||
            (t.inventoryItemName?.toLowerCase().contains(query) ?? false) ||
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.retailTransaction),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transaksi'),
            Tab(text: 'Inventaris'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Transaksi
          _buildTransactionTab(context),

          // Tab Inventaris
          _buildInventoryTab(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.pushNamed(context, AppRoutes.retailForm);
          } else {
            Navigator.pushNamed(context, AppRoutes.inventoryForm);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Transaksi' : 'Barang'),
      ),
    );
  }

  Widget _buildTransactionTab(BuildContext context) {
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
    final totalSales = filteredTransactions.fold<double>(
      0,
      (sum, t) => sum + t.amount,
    );
    final totalItems = filteredTransactions.fold<int>(
      0,
      (sum, t) => sum + t.quantity,
    );

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari transaksi atau barang...',
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
                  child: _buildSummaryItem(
                    theme,
                    icon: Icons.shopping_bag,
                    label: 'Penjualan',
                    value: Formatters.formatCurrency(totalSales),
                  ),
                ),
                Container(width: 1, height: 40, color: theme.dividerColor),
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    icon: Icons.inventory_2,
                    label: 'Item Terjual',
                    value: totalItems.toString(),
                  ),
                ),
                Container(width: 1, height: 40, color: theme.dividerColor),
                Expanded(
                  child: _buildSummaryItem(
                    theme,
                    icon: Icons.trending_up,
                    label: 'Profit',
                    value: Formatters.formatCurrency(totalProfit),
                    valueColor: AppColors.success,
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
                  ? _buildEmptyState(
                      context,
                      icon: Icons.store_outlined,
                      message: _searchQuery.isNotEmpty || _dateFilter != null
                          ? 'Tidak ada transaksi yang cocok'
                          : 'Belum ada transaksi ritel',
                    )
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
    );
  }

  Widget _buildInventoryTab(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final items = inventoryProvider.activeItems;

    // Calculate summary
    final totalItems = items.length;
    final totalStock = items.fold<int>(0, (sum, item) => sum + item.stock);
    final totalValue = items.fold<double>(
      0,
      (sum, item) => sum + item.stockValueSell,
    );
    final lowStockCount = inventoryProvider.lowStockItems.length;

    return Column(
      children: [
        // Summary Cards
        Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  icon: Icons.category,
                  label: 'Jenis',
                  value: totalItems.toString(),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  theme,
                  icon: Icons.inventory,
                  label: 'Stok',
                  value: totalStock.toString(),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  theme,
                  icon: Icons.warning_amber,
                  label: 'Rendah',
                  value: lowStockCount.toString(),
                  color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
        ),

        // Total Value
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Nilai Stok',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                Formatters.formatCurrency(totalValue),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Inventory List
        Expanded(
          child: inventoryProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: Icons.inventory_2_outlined,
                      message: 'Belum ada barang',
                      action: 'Tambah Barang',
                      onAction: () => Navigator.pushNamed(
                        context,
                        AppRoutes.inventoryForm,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => inventoryProvider.loadItems(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildInventoryCard(context, item);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.inventoryItemName ??
                              transaction.description ??
                              'Penjualan Barang',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (transaction.quantity > 1)
                          Text(
                            'x${transaction.quantity} item',
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

              // Footer
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
                  if (transaction.buyerName != null) ...[
                    const SizedBox(width: 8),
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
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    final isLowStock = item.isLowStock;
    final isOutOfStock = item.isOutOfStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.inventoryDetail,
            arguments: item,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? AppColors.error.withOpacity(0.1)
                      : isLowStock
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: isOutOfStock
                      ? AppColors.error
                      : isLowStock
                          ? AppColors.warning
                          : AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Stok: ${item.stock} ${item.unit}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOutOfStock
                                ? AppColors.error
                                : isLowStock
                                    ? AppColors.warning
                                    : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isLowStock || isOutOfStock
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (isOutOfStock || isLowStock) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? AppColors.error.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOutOfStock ? 'HABIS' : 'RENDAH',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isOutOfStock
                                    ? AppColors.error
                                    : AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(item.sellPrice),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Profit: ${Formatters.formatCurrency(item.profitPerItem)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

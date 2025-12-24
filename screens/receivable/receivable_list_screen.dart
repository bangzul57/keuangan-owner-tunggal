import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/receivable.dart';
import '../../providers/receivable_provider.dart';

/// Screen daftar piutang
class ReceivableListScreen extends StatefulWidget {
  const ReceivableListScreen({super.key});

  @override
  State<ReceivableListScreen> createState() => _ReceivableListScreenState();
}

class _ReceivableListScreenState extends State<ReceivableListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<ReceivableProvider>().loadReceivables();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Receivable> _filterReceivables(List<Receivable> receivables) {
    if (_searchQuery.isEmpty) return receivables;

    final query = _searchQuery.toLowerCase();
    return receivables.where((r) {
      return r.buyerName.toLowerCase().contains(query) ||
          (r.phoneNumber?.contains(query) ?? false) ||
          (r.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receivableProvider = context.watch<ReceivableProvider>();

    final unpaidList = _filterReceivables(receivableProvider.unpaidReceivables);
    final paidList = _filterReceivables(receivableProvider.paidReceivables);
    final overdueList = _filterReceivables(receivableProvider.overdueReceivables);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.receivable),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum Lunas'),
                  if (unpaidList.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _buildBadge(unpaidList.length.toString(), AppColors.warning),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Jatuh Tempo'),
                  if (overdueList.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _buildBadge(overdueList.length.toString(), AppColors.error),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Lunas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama pembeli...',
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

          // Summary Card
          _buildSummaryCard(context, receivableProvider),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Belum Lunas
                _buildReceivableList(context, unpaidList, 'Belum ada piutang'),

                // Jatuh Tempo
                _buildReceivableList(
                  context,
                  overdueList,
                  'Tidak ada piutang jatuh tempo',
                  showOverdueWarning: true,
                ),

                // Lunas
                _buildReceivableList(context, paidList, 'Belum ada piutang lunas'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addReceivable);
        },
        icon: const Icon(Icons.add),
        label: const Text('Piutang Baru'),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ReceivableProvider provider) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Piutang',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(provider.totalOutstanding),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sudah Dibayar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(provider.totalPaid),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivableList(
    BuildContext context,
    List<Receivable> receivables,
    String emptyMessage, {
    bool showOverdueWarning = false,
  }) {
    final provider = context.watch<ReceivableProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (receivables.isEmpty) {
      return _buildEmptyState(context, emptyMessage);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: receivables.length,
        itemBuilder: (context, index) {
          final receivable = receivables[index];
          return _buildReceivableCard(context, receivable, showOverdueWarning);
        },
      ),
    );
  }

  Widget _buildReceivableCard(
    BuildContext context,
    Receivable receivable,
    bool showOverdueWarning,
  ) {
    final theme = Theme.of(context);
    final isOverdue = receivable.isOverdue;
    final statusColor = _getStatusColor(receivable.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue && showOverdueWarning
            ? const BorderSide(color: AppColors.error, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.receivableDetail,
            arguments: receivable,
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
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Text(
                      receivable.buyerName[0].toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receivable.buyerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (receivable.phoneNumber != null)
                          Text(
                            receivable.phoneNumber!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      receivable.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Amount Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sisa Hutang',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.formatCurrency(receivable.remainingAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.formatCurrency(receivable.totalAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Progress Bar
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: receivable.paymentPercentage / 100,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    receivable.isPaid ? AppColors.success : AppColors.info,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${receivable.paymentPercentage.toStringAsFixed(0)}% terbayar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              // Due Date
              if (receivable.dueDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning : Icons.event,
                      size: 14,
                      color: isOverdue
                          ? AppColors.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.formatDueDuration(receivable.dueDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? AppColors.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
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
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ReceivableStatus status) {
    switch (status) {
      case ReceivableStatus.pending:
        return AppColors.warning;
      case ReceivableStatus.partial:
        return AppColors.info;
      case ReceivableStatus.paid:
        return AppColors.success;
      case ReceivableStatus.cancelled:
        return AppColors.error;
    }
  }
}

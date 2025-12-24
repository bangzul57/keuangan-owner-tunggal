import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../models/receivable.dart';
import '../../providers/receivable_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/primary_button.dart';

/// Screen detail piutang
class ReceivableDetailScreen extends StatefulWidget {
  const ReceivableDetailScreen({super.key});

  @override
  State<ReceivableDetailScreen> createState() => _ReceivableDetailScreenState();
}

class _ReceivableDetailScreenState extends State<ReceivableDetailScreen> {
  Receivable? _receivable;
  List<ReceivablePayment> _payments = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Receivable) {
      final provider = context.read<ReceivableProvider>();
      final detail = await provider.loadReceivableWithPayments(args.id!);
      final payments = await provider.loadPayments(args.id!);

      if (mounted) {
        setState(() {
          _receivable = detail ?? args;
          _payments = payments;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelReceivable() async {
    if (_receivable == null) return;

    final reason = await InputDialog.show(
      context: context,
      title: 'Batalkan Piutang',
      message: 'Masukkan alasan pembatalan:',
      hintText: 'Alasan pembatalan',
      confirmText: 'Batalkan',
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Alasan wajib diisi';
        }
        return null;
      },
    );

    if (reason == null || reason.isEmpty) return;

    final provider = context.read<ReceivableProvider>();
    final success = await provider.cancelReceivable(_receivable!.id!, reason);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Piutang berhasil dibatalkan'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Gagal membatalkan piutang'),
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
        appBar: AppBar(title: const Text('Detail Piutang')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_receivable == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Piutang')),
        body: const Center(child: Text('Piutang tidak ditemukan')),
      );
    }

    final receivable = _receivable!;
    final isOverdue = receivable.isOverdue;
    final isPaid = receivable.isPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Piutang'),
        actions: [
          if (!isPaid)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') {
                  _cancelReceivable();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Batalkan Piutang'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(theme, receivable, isOverdue, isPaid),

              const SizedBox(height: 16),

              // Buyer Info
              _buildInfoCard(theme, receivable),

              const SizedBox(height: 16),

              // Amount Details
              _buildAmountCard(theme, receivable),

              const SizedBox(height: 16),

              // Payment History
              _buildPaymentHistory(theme),

              const SizedBox(height: 24),

              // Action Button
              if (!isPaid)
                PrimaryButton(
                  text: 'Terima Pembayaran',
                  icon: Icons.payments,
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.receivePayment,
                      arguments: receivable,
                    );
                    _loadData();
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    ThemeData theme,
    Receivable receivable,
    bool isOverdue,
    bool isPaid,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      statusText = 'Lunas';
    } else if (isOverdue) {
      statusColor = AppColors.error;
      statusIcon = Icons.warning;
      statusText = 'Jatuh Tempo';
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule;
      statusText = 'Belum Lunas';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: theme.textTheme.titleLarge?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sisa Hutang',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            Formatters.formatCurrency(receivable.remainingAmount),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: receivable.paymentPercentage / 100,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${receivable.paymentPercentage.toStringAsFixed(1)}% terbayar',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, Receivable receivable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Pembeli',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(theme, Icons.person, 'Nama', receivable.buyerName),
            if (receivable.phoneNumber != null)
              _buildInfoRow(
                theme,
                Icons.phone,
                'Telepon',
                Formatters.formatPhoneNumber(receivable.phoneNumber),
              ),
            if (receivable.dueDate != null)
              _buildInfoRow(
                theme,
                Icons.event,
                'Jatuh Tempo',
                Formatters.formatDate(receivable.dueDate),
              ),
            _buildInfoRow(
              theme,
              Icons.access_time,
              'Dibuat',
              Formatters.formatDateTime(receivable.createdAt),
            ),
            if (receivable.notes != null && receivable.notes!.isNotEmpty)
              _buildInfoRow(theme, Icons.notes, 'Catatan', receivable.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
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
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, Receivable receivable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rincian Nominal',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildAmountRow(
              theme,
              'Total Piutang',
              Formatters.formatCurrency(receivable.totalAmount),
            ),
            _buildAmountRow(
              theme,
              'Sudah Dibayar',
              Formatters.formatCurrency(receivable.paidAmount),
              valueColor: AppColors.success,
            ),
            const Divider(),
            _buildAmountRow(
              theme,
              'Sisa Hutang',
              Formatters.formatCurrency(receivable.remainingAmount),
              isBold: true,
              valueColor: receivable.remainingAmount > 0 ? AppColors.error : null,
            ),
            if (receivable.profitAmount > 0)
              _buildAmountRow(
                theme,
                'Profit (Tercatat)',
                Formatters.formatCurrency(receivable.profitAmount),
                valueColor: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(ThemeData theme) {
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
                  'Riwayat Pembayaran',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_payments.length} pembayaran',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada pembayaran',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return _buildPaymentItem(theme, payment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(ThemeData theme, ReceivablePayment payment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check,
              color: AppColors.success,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.formatCurrency(payment.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${PaymentMethod.fromValue(payment.paymentMethod).label} • ${payment.destinationAccountName ?? 'Kas'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.formatDate(payment.paymentDate),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

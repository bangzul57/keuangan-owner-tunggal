import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/money_input.dart';

/// Screen pengaturan aplikasi
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tampilan
          _buildSectionHeader(context, 'Tampilan'),
          _buildSettingsCard(
            context,
            children: [
              SwitchListTile(
                title: const Text('Mode Gelap'),
                subtitle: const Text('Gunakan tema gelap'),
                value: settingsProvider.isDarkMode,
                onChanged: (value) {
                  settingsProvider.setDarkMode(value);
                },
                secondary: Icon(
                  settingsProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Mode Aplikasi
          _buildSectionHeader(context, 'Mode Aplikasi'),
          _buildSettingsCard(
            context,
            children: [
              SwitchListTile(
                title: const Text('Mode Digital'),
                subtitle: const Text('Fitur transaksi e-wallet & bank'),
                value: settingsProvider.isDigitalEnabled,
                onChanged: (value) async {
                  final success = await settingsProvider.setDigitalMode(value);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          settingsProvider.errorMessage ?? 'Gagal mengubah pengaturan',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                secondary: const Icon(Icons.smartphone),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Mode Ritel'),
                subtitle: const Text('Fitur penjualan barang & inventaris'),
                value: settingsProvider.isRetailEnabled,
                onChanged: (value) async {
                  final success = await settingsProvider.setRetailMode(value);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          settingsProvider.errorMessage ?? 'Gagal mengubah pengaturan',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                secondary: const Icon(Icons.store),
              ),
            ],
          ),
          _buildModeInfo(context, settingsProvider.appMode),

          const SizedBox(height: 24),

          // Biaya Admin Default
          _buildSectionHeader(context, 'Biaya Admin Default'),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Biaya Admin'),
                subtitle: Text(
                  settingsProvider.usePercentageAdmin
                      ? '${settingsProvider.defaultAdminPercentage}%'
                      : Formatters.formatCurrency(settingsProvider.defaultAdminFee),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAdminFeeDialog(context, settingsProvider),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Gunakan Persentase'),
                subtitle: const Text('Hitung admin berdasarkan persen'),
                value: settingsProvider.usePercentageAdmin,
                onChanged: (value) {
                  settingsProvider.setUsePercentageAdmin(value);
                },
                secondary: const Icon(Icons.percent),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Inventaris
          if (settingsProvider.isRetailEnabled) ...[
            _buildSectionHeader(context, 'Inventaris'),
            _buildSettingsCard(
              context,
              children: [
                ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: const Text('Batas Stok Rendah'),
                  subtitle: Text('${settingsProvider.lowStockThreshold} item'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLowStockDialog(context, settingsProvider),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Data
          _buildSectionHeader(context, 'Data'),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Backup Data'),
                subtitle: const Text('Simpan data ke file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement backup
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur backup akan segera hadir'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore Data'),
                subtitle: const Text('Pulihkan data dari file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement restore
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur restore akan segera hadir'),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: const Text(
                  'Reset Semua Data',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text('Hapus semua data aplikasi'),
                onTap: () => _showResetDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tentang
          _buildSectionHeader(context, 'Tentang'),
          _buildSettingsCard(
            context,
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text(AppStrings.appName),
                subtitle: Text('Versi ${AppStrings.appVersion}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Deskripsi'),
                subtitle: const Text(AppStrings.appDescription),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildModeInfo(BuildContext context, AppMode mode) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode saat ini: ${mode.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdminFeeDialog(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final controller = TextEditingController(
      text: provider.usePercentageAdmin
          ? provider.defaultAdminPercentage.toString()
          : Formatters.formatNumber(provider.defaultAdminFee),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Biaya Admin Default'),
          content: provider.usePercentageAdmin
              ? TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Persentase',
                    suffixText: '%',
                  ),
                )
              : MoneyInput(
                  controller: controller,
                  labelText: 'Nominal',
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (provider.usePercentageAdmin) {
        final percentage = double.tryParse(controller.text) ?? 0;
        await provider.setDefaultAdminPercentage(percentage);
      } else {
        final fee = double.tryParse(
              controller.text.replaceAll('.', '').replaceAll(',', '.'),
            ) ??
            0;
        await provider.setDefaultAdminFee(fee);
      }
    }

    controller.dispose();
  }

  Future<void> _showLowStockDialog(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final controller = TextEditingController(
      text: provider.lowStockThreshold.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Batas Stok Rendah'),
          content: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              suffixText: 'item',
              helperText: 'Notifikasi akan muncul jika stok di bawah nilai ini',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final threshold = int.tryParse(controller.text) ?? 5;
      await provider.setLowStockThreshold(threshold);
    }

    controller.dispose();
  }

  Future<void> _showResetDialog(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Reset Semua Data',
      message: 'PERINGATAN: Semua data akan dihapus permanen dan tidak dapat dikembalikan.\n\nApakah Anda yakin ingin melanjutkan?',
      confirmText: 'Reset',
      type: ConfirmDialogType.danger,
      icon: Icons.delete_forever,
    );

    if (confirmed && context.mounted) {
      // TODO: Implement reset
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur reset akan segera hadir'),
        ),
      );
    }
  }
}

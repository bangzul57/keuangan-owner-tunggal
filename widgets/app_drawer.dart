import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/formatters.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/receivable/receivable_list_screen.dart';

/// Drawer navigasi utama aplikasi
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();

    return Drawer(
      child: Column(
        children: [
          // Header
          _buildHeader(context, theme, accountProvider),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Dashboard
                _buildMenuItem(
                  context: context,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  title: AppStrings.dashboard,
                  route: AppRoutes.dashboard,
                ),

                const Divider(height: 1),

                // Section: Transaksi
                _buildSectionHeader(context, 'Transaksi'),

                // Digital Transaction (jika enabled)
                if (settingsProvider.isDigitalEnabled)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.smartphone_outlined,
                    selectedIcon: Icons.smartphone,
                    title: AppStrings.digitalTransaction,
                    route: AppRoutes.digitalList,
                  ),

                // Retail Transaction (jika enabled)
                if (settingsProvider.isRetailEnabled)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.store_outlined,
                    selectedIcon: Icons.store,
                    title: AppStrings.retailTransaction,
                    route: AppRoutes.retailList,
                  ),

                // Transfer
                _buildMenuItem(
                  context: context,
                  icon: Icons.swap_horiz_outlined,
                  selectedIcon: Icons.swap_horiz,
                  title: AppStrings.transfer,
                  route: AppRoutes.transferForm,
                ),

                // Prive
                _buildMenuItem(
                  context: context,
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet,
                  title: AppStrings.prive,
                  route: AppRoutes.priveForm,
                ),

                const Divider(height: 1),

                // Section: Piutang & Inventaris
                _buildSectionHeader(context, 'Manajemen'),

                // Hutang Pelanggan
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Hutang Pelanggan'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReceivableListScreen(),
                      ),
                    );
                  },
                ),

                // Inventaris (jika retail enabled)
                if (settingsProvider.isRetailEnabled)
                  _buildMenuItem(
                    context: context,
                    icon: Icons.inventory_2_outlined,
                    selectedIcon: Icons.inventory_2,
                    title: AppStrings.inventory,
                    route: AppRoutes.inventoryList,
                    badge: _getLowStockBadge(context),
                  ),

                const Divider(height: 1),

                // Section: Laporan
                _buildSectionHeader(context, 'Laporan'),

                // Buku Besar
                _buildMenuItem(
                  context: context,
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  title: AppStrings.ledger,
                  route: AppRoutes.ledger,
                ),

                // Laporan (coming soon)
                _buildMenuItem(
                  context: context,
                  icon: Icons.analytics_outlined,
                  selectedIcon: Icons.analytics,
                  title: AppStrings.reports,
                  route: AppRoutes.reports,
                  enabled: false,
                ),

                const Divider(height: 1),

                // Settings
                _buildMenuItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  title: AppStrings.settings,
                  route: AppRoutes.settings,
                ),
              ],
            ),
          ),

          // Footer
          _buildFooter(context, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AccountProvider accountProvider,
  ) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Icon & Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'v${AppStrings.appVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Total Balance
          Text(
            'Total Saldo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.formatCurrency(accountProvider.totalAssetBalance),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String route,
    Widget? badge,
    bool enabled = true,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected
              ? theme.colorScheme.primary
              : enabled
                  ? null
                  : theme.disabledColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.primary
                : enabled
                    ? null
                    : theme.disabledColor,
          ),
        ),
        trailing: badge,
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: enabled
            ? () {
                Navigator.pop(context); // Close drawer
                if (!isSelected) {
                  Navigator.pushNamed(context, route);
                }
              }
            : null,
      ),
    );
  }

  Widget? _getLowStockBadge(BuildContext context) {
    // TODO: Implement dengan InventoryProvider
    // final inventoryProvider = context.watch<InventoryProvider>();
    // final lowStockCount = inventoryProvider.lowStockItems.length;
    // if (lowStockCount > 0) {
    //   return _buildBadge(context, lowStockCount.toString(), AppColors.warning);
    // }
    return null;
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.appDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

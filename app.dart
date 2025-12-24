import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'providers/settings_provider.dart';
import 'screens/accounts/account_detail_screen.dart';
import 'screens/accounts/add_asset_account_screen.dart';
import 'screens/accounts/edit_balance_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/digital/digital_form_screen.dart';
import 'screens/digital/digital_list_screen.dart';
import 'screens/digital/digital_topup_screen.dart';
import 'screens/ledger/ledger_detail_screen.dart';
import 'screens/ledger/ledger_screen.dart';
import 'screens/ledger/transaction_detail_screen.dart';
import 'screens/prive/prive_form_screen.dart';
import 'screens/receivable/add_receivable_screen.dart';
import 'screens/receivable/receivable_detail_screen.dart';
import 'screens/receivable/receivable_list_screen.dart';
import 'screens/receivable/receive_payment_screen.dart';
import 'screens/retail/retail_form_screen.dart';
import 'screens/retail/retail_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/transfer/transfer_form_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(settingsProvider.isDarkMode),
          initialRoute: AppRoutes.dashboard,
          routes: _buildRoutes(),
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (_) => const _NotFoundScreen(),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(bool isDarkMode) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      // Dashboard
      AppRoutes.dashboard: (_) => const DashboardScreen(),

      // Accounts
      AppRoutes.addAssetAccount: (_) => const AddAssetAccountScreen(),
      AppRoutes.accountDetail: (_) => const AccountDetailScreen(),
      AppRoutes.editBalance: (_) => const EditBalanceScreen(),

      // Digital
      AppRoutes.digitalList: (_) => const DigitalListScreen(),
      AppRoutes.digitalForm: (_) => const DigitalFormScreen(),
      AppRoutes.digitalTopup: (_) => const DigitalTopupScreen(),

      // Retail
      AppRoutes.retailList: (_) => const RetailListScreen(),
      AppRoutes.retailForm: (_) => const RetailFormScreen(),

      // Receivable (Piutang)
      AppRoutes.receivableList: (_) => const ReceivableListScreen(),
      AppRoutes.addReceivable: (_) => const AddReceivableScreen(),
      AppRoutes.receivableDetail: (_) => const ReceivableDetailScreen(),
      AppRoutes.receivePayment: (_) => const ReceivePaymentScreen(),

      // Transfer
      AppRoutes.transferForm: (_) => const TransferFormScreen(),

      // Prive (Penarikan Pribadi)
      AppRoutes.priveForm: (_) => const PriveFormScreen(),

      // Ledger
      AppRoutes.ledger: (_) => const LedgerScreen(),
      AppRoutes.ledgerDetail: (_) => const LedgerDetailScreen(),
      AppRoutes.transactionDetail: (_) => const TransactionDetailScreen(),

      // Settings
      AppRoutes.settings: (_) => const SettingsScreen(),
    };
  }
}

/// Screen untuk menangani route yang tidak ditemukan
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Halaman Tidak Ditemukan')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Halaman tidak ditemukan',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.dashboard,
                (route) => false,
              ),
              icon: const Icon(Icons.home),
              label: const Text('Kembali ke Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

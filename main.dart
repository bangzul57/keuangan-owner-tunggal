import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/db_helper.dart';
import 'providers/account_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/receivable_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize database
  await DBHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        // Settings Provider (independent)
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider()..loadSettings(),
        ),

        // Account Provider (independent)
        ChangeNotifierProvider<AccountProvider>(
          create: (_) => AccountProvider()..loadAccounts(),
        ),

        // Inventory Provider (independent)
        ChangeNotifierProvider<InventoryProvider>(
          create: (_) => InventoryProvider()..loadItems(),
        ),

        // Ledger Provider (independent)
        ChangeNotifierProvider<LedgerProvider>(
          create: (_) => LedgerProvider()..loadEntries(),
        ),

        // Transaction Provider (depends on Account & Inventory)
        ChangeNotifierProxyProvider2<AccountProvider, InventoryProvider,
            TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, accountProvider, inventoryProvider, transactionProvider) {
            transactionProvider ??= TransactionProvider();
            transactionProvider.updateDependencies(
              accountProvider,
              inventoryProvider,
            );
            return transactionProvider;
          },
        ),

        // Receivable Provider (depends on Account)
        ChangeNotifierProxyProvider<AccountProvider, ReceivableProvider>(
          create: (_) => ReceivableProvider()..loadReceivables(),
          update: (_, accountProvider, receivableProvider) {
            receivableProvider ??= ReceivableProvider();
            receivableProvider.updateDependencies(accountProvider);
            return receivableProvider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

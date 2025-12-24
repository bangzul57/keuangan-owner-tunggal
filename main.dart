import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/database/db_helper.dart';
import 'providers/account_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only (optional, untuk konsistensi UI)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi database
  await DBHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => AccountProvider()..loadAccounts()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()..loadEntries()),
        ChangeNotifierProxyProvider2<AccountProvider, InventoryProvider,
            TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, accountProvider, inventoryProvider, transactionProvider) {
            return transactionProvider!
              ..updateDependencies(accountProvider, inventoryProvider);
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

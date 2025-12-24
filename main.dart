import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/account_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/transaction_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: const LedgerApp(),
    ),
  );
}

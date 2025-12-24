import 'package:flutter/material.dart';

import '../screens/ledger/ledger_screen.dart';
import '../screens/receivable/receivable_list_screen.dart';
import '../screens/receivable/add_receivable_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green,
            ),
            child: Text(
              'Keuangan Ledger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context); // tutup drawer
            },
          ),

          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Riwayat Transaksi'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LedgerScreen(),
                ),
              );
            },
          ),

          ListTile(
  leading: const Icon(Icons.people_alt_outlined),
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

ListTile(
  leading: const Icon(Icons.add_card),
  title: const Text('Hutang Baru'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddReceivableScreen(),
      ),
    );
  },
),


        ],
      ),
    );
  }
}

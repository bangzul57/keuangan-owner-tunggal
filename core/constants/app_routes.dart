import 'package:flutter/material.dart';

import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/accounts/add_asset_account_screen.dart';
import '../../screens/digital/digital_form_screen.dart';

class AppRoutes {
  static const dashboard = '/';
  static const addAccount = '/add-account';
  static const digitalSale = '/digital-sale';

  static final Map<String, WidgetBuilder> routes = {
    dashboard: (_) => const DashboardScreen(),
    addAccount: (_) => const AddAssetAccountScreen(),
    digitalSale: (_) => const DigitalFormScreen(),
  };
}

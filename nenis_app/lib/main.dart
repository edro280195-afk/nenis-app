import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es');
  await initializeDateFormatting('es_MX');
  runApp(const ProviderScope(child: NenisApp()));
}

class NenisApp extends ConsumerWidget {
  const NenisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(activeBrandProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: "Neni's App",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand: brand),
      routerConfig: router,
    );
  }
}

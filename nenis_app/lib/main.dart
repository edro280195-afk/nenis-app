import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/deeplinks/deep_link_service.dart';
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

class NenisApp extends ConsumerStatefulWidget {
  const NenisApp({super.key});

  @override
  ConsumerState<NenisApp> createState() => _NenisAppState();
}

class _NenisAppState extends ConsumerState<NenisApp> {
  @override
  void initState() {
    super.initState();
    // Arranca la captura de deep links: link inicial (cold start), stream
    // (warm), Install Referrer y re-siembra del token pendiente persistido.
    ref.read(deepLinkServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
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

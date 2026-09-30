import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/auth/auth_controller.dart';
import 'core/deeplinks/deep_link_service.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es');
  await initializeDateFormatting('es_MX');
  try {
    // Firebase se usa para Auth por teléfono y notificaciones push. Si falta
    // la configuración nativa, el proveedor de Auth mostrará un error seguro;
    // el resto de la app sigue funcionando.
    await Firebase.initializeApp();
  } catch (_) {}
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
    // Listeners de push (foreground/tap) — el registro del token del
    // dispositivo pasa por AuthController tras el login.
    ref.read(pushServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(activeBrandProvider);
    final router = ref.watch(routerProvider);
    // Registra el token de push cada vez que aparece una sesión: al iniciar
    // sesión y también al abrir la app con la sesión ya guardada (antes solo
    // se registraba en el login, así que el token nunca se refrescaba).
    ref.listen(authControllerProvider, (previous, next) {
      final hadSession = previous?.value != null;
      if (!hadSession && next.value != null) {
        unawaited(ref.read(pushServiceProvider).registerCurrentToken());
      }
    });
    return MaterialApp.router(
      title: "Neni's App",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand: brand),
      routerConfig: router,
    );
  }
}

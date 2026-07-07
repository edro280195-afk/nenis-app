import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../deeplinks/deep_link_service.dart';
import '../../features/auth/screens/auth_welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/confirm_screen.dart';
import '../../features/auth/screens/claim_profile_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/store/screens/store_screen.dart';
import '../../features/live/screens/live_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/screens/order_create_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/tracking/screens/tracking_screen.dart';
import '../../features/tracking/screens/order_link_screen.dart';
import '../../features/points/screens/points_screen.dart';
import '../../features/tandas/screens/tandas_screen.dart';
import '../../features/raffles/screens/raffles_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/addresses/screens/address_edit_screen.dart';
import '../../features/addresses/screens/addresses_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/reserve/screens/reserve_screen.dart';
import '../../features/routes/screens/seller_routes_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// Rutas de acceso (sin sesión). El resto exige estar autenticado, salvo
/// rastreo público por token.
const _authRoutes = {
  '/splash',
  '/welcome',
  '/login',
  '/register',
  '/forgot-password',
  '/confirm',
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  // Un pedido que llega por deep link también dispara re-evaluación de rutas.
  ref.listen(pendingDeepLinkProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final path = state.uri.path;

      // Normaliza el short-link /o/{token} al destino interno /pedido/{token}.
      if (path.startsWith('/o/')) {
        final token = path.substring(3).trim();
        if (token.isNotEmpty) return '/pedido/$token';
      }

      final hasTrackingToken =
          state.uri.queryParameters['token']?.trim().isNotEmpty ?? false;
      final isPublicTracking =
          path.startsWith('/tracking/') && hasTrackingToken;

      if (isPublicTracking) return null;

      final pendingToken = ref.read(pendingDeepLinkProvider);
      final hasPending = pendingToken != null && pendingToken.isNotEmpty;

      // Cargando la sesión persistida -> splash (el pendiente se conserva).
      if (auth.isLoading || !auth.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }

      final session = auth.value;
      if (session == null) {
        // Deep link sin sesión: orillar a crear cuenta para desbloquear el
        // pedido, dejando pasar las pantallas de acceso.
        if (hasPending) {
          return _authRoutes.contains(loc) ? null : '/welcome';
        }
        if (loc == '/splash') return '/login';
        if (loc == '/confirm' &&
            ref.read(authControllerProvider.notifier).pendingPhone == null) {
          return '/login';
        }
        return _authRoutes.contains(loc) ? null : '/login';
      }

      // Autenticada con un pedido pendiente por deep link: tiene prioridad
      // sobre el resto (incluido el reclamo por teléfono).
      if (hasPending) {
        final target = '/pedido/$pendingToken';
        return loc == target ? null : target;
      }

      // Restringir ruta de reparto solo a vendedoras (miembros de negocio)
      if (loc == '/routes' && !session.hasMembership) return '/home';

      // Recién confirmada por WhatsApp y sin negocio propio -> a reclamar perfil.
      if (loc == '/confirm' && !session.hasMembership) return '/claim';
      // Autenticada: no se queda en pantallas de acceso.
      if (_authRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const AuthWelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/confirm',
        builder: (context, state) => const ConfirmScreen(),
      ),
      GoRoute(
        path: '/claim',
        builder: (context, state) => const ClaimProfileScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentRoute: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/routes',
            builder: (context, state) => const SellerRoutesScreen(),
          ),
          GoRoute(
            path: '/store/:businessId',
            builder: (context, state) =>
                StoreScreen(businessId: state.pathParameters['businessId']!),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/points',
            builder: (context, state) => const PointsScreen(),
          ),
          GoRoute(
            path: '/tandas',
            builder: (context, state) => const TandasScreen(),
          ),
          GoRoute(
            path: '/raffles',
            builder: (context, state) => const RafflesScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/live/:sessionId',
        builder: (context, state) =>
            LiveScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/orders/new',
        builder: (context, state) => const OrderCreateScreen(),
      ),
      GoRoute(
        path: '/orders/detail/:id',
        builder: (context, state) => OrderDetailScreen(
          orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        builder: (context, state) => TrackingScreen(
          orderId: state.pathParameters['orderId']!,
          accessToken: state.uri.queryParameters['token'],
        ),
      ),
      // Destino del enlace del pedido (deep link). `/o/:token` es red de
      // seguridad: normalmente el redirect reescribe /o/ a /pedido/.
      GoRoute(
        path: '/pedido/:token',
        builder: (context, state) =>
            OrderLinkScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/o/:token',
        builder: (context, state) =>
            OrderLinkScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/reserve/:businessId/:productId',
        builder: (context, state) => ReserveScreen(
          businessId: state.pathParameters['businessId']!,
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const AddressesScreen(),
      ),
      GoRoute(
        path: '/addresses/:clientId',
        builder: (context, state) =>
            AddressEditScreen(clientId: state.pathParameters['clientId']!),
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_repository.dart';
import '../deeplinks/deep_link_service.dart';
import '../../features/auth/screens/auth_welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/login_otp_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/confirm_screen.dart';
import '../../features/auth/screens/claim_profile_screen.dart';
import '../../features/claim/screens/claim_order_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/store/screens/store_screen.dart';
import '../../features/live/screens/live_screen.dart';
import '../../features/live/screens/seller_live_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/screens/order_create_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/labels/screens/label_batch_print_screen.dart';
import '../../features/labels/screens/label_template_editor_screen.dart';
import '../../features/labels/data/label_print_models.dart';
import '../../features/labels/data/label_template_models.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/tracking/screens/tracking_screen.dart';
import '../../features/tracking/screens/order_link_screen.dart';
import '../../features/points/screens/points_screen.dart';
import '../../features/tandas/screens/tandas_screen.dart';
import '../../features/raffles/screens/raffles_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/account/screens/seller_settings_screens.dart';
import '../../features/account/screens/seller_payment_settings_screen.dart';
import '../../features/addresses/screens/address_edit_screen.dart';
import '../../features/addresses/screens/addresses_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/reserve/screens/reserve_screen.dart';
import '../../features/routes/screens/seller_routes_screen.dart';
import '../../features/clients/screens/seller_clients_screen.dart';
import '../../features/seller_updates/screens/seller_updates_screen.dart';
import '../../features/seller_vip/screens/seller_vip_screen.dart';
import '../../features/subscription/screens/my_plan_screen.dart';
import '../../features/subscription/screens/mp_checkout_webview_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// Rutas de acceso (sin sesión). El resto exige estar autenticado, salvo
/// rastreo público por token.
const _authRoutes = {
  '/splash',
  '/welcome',
  '/login',
  '/login-otp',
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
  ref.listen(pendingInventoryDeepLinkProvider, (_, _) => refresh.value++);

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
      final pendingInventory = ref.read(pendingInventoryDeepLinkProvider);

      // Cargando la sesión persistida -> splash (el pendiente se conserva).
      if (auth.isLoading || !auth.hasValue) {
        return loc == '/splash' ? null : '/splash';
      }

      final session = auth.value;
      if (session == null) {
        // Deep link sin sesión: al onboarding contextual "reclama tu pedido"
        // (passwordless). Deja pasar esa pantalla y el acceso manual.
        if (hasPending) {
          if (loc == '/claim-order' || _authRoutes.contains(loc)) return null;
          return '/claim-order';
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

      if (pendingInventory != null) {
        final ownsBusiness = session.memberships.any(
          (membership) => membership.businessId == pendingInventory.businessId,
        );
        if (!ownsBusiness) return '/home';
        if (session.activeBusinessId != pendingInventory.businessId) {
          ref
              .read(authControllerProvider.notifier)
              .setActiveBusiness(pendingInventory.businessId);
        }
        final target =
            '/seller/inventory?tag=${Uri.encodeComponent(pendingInventory.token)}';
        final isTarget =
            loc == '/seller/inventory' &&
            state.uri.queryParameters['tag'] == pendingInventory.token;
        return isTarget ? null : target;
      }

      // Restringir rutas de gestión solo a vendedoras (miembros de negocio).
      if ((loc == '/routes' ||
              loc == '/clients' ||
              loc.startsWith('/seller/')) &&
          !session.hasMembership) {
        return '/home';
      }
      if (loc == '/routes' && !session.canAccessRoutes) return '/home';
      if (loc == '/seller/labels/editor' && !session.canManageLabels) {
        return '/seller/inventory';
      }

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
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const AuthWelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/login-otp',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const LoginOtpScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: RegisterScreen(
            initialRole: state.uri.queryParameters['role'] == 'seller'
                ? FacebookAccountType.seller
                : FacebookAccountType.client,
          ),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const PasswordResetScreen(),
        ),
      ),
      GoRoute(
        path: '/confirm',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const ConfirmScreen()),
      ),
      GoRoute(
        path: '/claim',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const ClaimProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/claim-order',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const ClaimOrderScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentRoute: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _pageTransition(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/routes',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const SellerRoutesScreen(),
            ),
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const SellerClientsScreen(),
            ),
          ),
          GoRoute(
            path: '/store/:businessId',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: StoreScreen(
                businessId: state.pathParameters['businessId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const OrdersScreen(),
            ),
          ),
          GoRoute(
            path: '/points',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const PointsScreen(),
            ),
          ),
          GoRoute(
            path: '/tandas',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const TandasScreen(),
            ),
          ),
          GoRoute(
            path: '/raffles',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const RafflesScreen(),
            ),
          ),
          GoRoute(
            path: '/account',
            pageBuilder: (context, state) => _pageTransition(
              key: state.pageKey,
              child: const AccountScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/live/:businessId',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: LiveScreen(businessId: state.pathParameters['businessId']!),
        ),
      ),
      GoRoute(
        path: '/orders/new',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const OrderCreateScreen(),
        ),
      ),
      GoRoute(
        path: '/orders/detail/:id',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: OrderDetailScreen(
            orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/tracking/:orderId',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: TrackingScreen(
            orderId: state.pathParameters['orderId']!,
            accessToken: state.uri.queryParameters['token'],
          ),
        ),
      ),
      GoRoute(
        path: '/pedido/:token',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: OrderLinkScreen(token: state.pathParameters['token']!),
        ),
      ),
      GoRoute(
        path: '/o/:token',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: OrderLinkScreen(token: state.pathParameters['token']!),
        ),
      ),
      GoRoute(
        path: '/reserve/:businessId/:productId',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: ReserveScreen(
            businessId: state.pathParameters['businessId']!,
            productId: state.pathParameters['productId']!,
          ),
          slideUp: true,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/payments',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const PaymentsScreen()),
      ),
      GoRoute(
        path: '/seller/settings',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/labels',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const LabelBatchPrintScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/labels/editor',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: LabelTemplateEditorScreen(
            kind: LabelTemplateKind.fromApi(
              state.uri.queryParameters['kind'] ?? 'OrderPackage',
            ),
            mediaSize: LabelMediaSize.fromApi(
              state.uri.queryParameters['mediaSize'] ?? 'Shipping4x6',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/seller/inventory',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: InventoryScreen(tagToken: state.uri.queryParameters['tag']),
        ),
      ),
      GoRoute(
        path: '/seller/settings/profile',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerStoreProfileSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/settings/payments',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerPaymentSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/settings/team',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerTeamSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/settings/preferences',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerPreferencesSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/plan',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const MyPlanScreen()),
      ),
      GoRoute(
        path: '/seller/plan/checkout',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: MpCheckoutWebViewScreen(
            planTier: state.uri.queryParameters['plan'] ?? 'Pro',
            periodicity: state.uri.queryParameters['periodicity'] ?? 'monthly',
          ),
          slideUp: true,
        ),
      ),
      GoRoute(
        path: '/seller/updates',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerUpdatesScreen(),
        ),
      ),
      GoRoute(
        path: '/seller/vip',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const SellerVipScreen()),
      ),
      GoRoute(
        path: '/seller/live',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: const SellerLiveScreen(),
        ),
      ),
      GoRoute(
        path: '/addresses',
        pageBuilder: (context, state) =>
            _pageTransition(key: state.pageKey, child: const AddressesScreen()),
      ),
      GoRoute(
        path: '/addresses/:clientId',
        pageBuilder: (context, state) => _pageTransition(
          key: state.pageKey,
          child: AddressEditScreen(clientId: state.pathParameters['clientId']!),
        ),
      ),
    ],
  );
});

Page<T> _pageTransition<T>({
  required LocalKey key,
  required Widget child,
  bool slideUp = false,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (slideUp) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      }
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.06),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
  );
}

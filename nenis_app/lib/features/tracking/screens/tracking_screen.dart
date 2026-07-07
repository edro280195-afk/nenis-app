import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/tracking_controller.dart';
import '../widgets/order_tracking_experience.dart';

/// Pantalla de seguimiento del pedido para la clienta.
/// Carga reactivamente el estado del pedido y delega a la experiencia de
/// seguimiento Nenis V3 (OrderTrackingExperience).
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId, this.accessToken});

  final String orderId;
  final String? accessToken;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Setea el token en el provider para que el controller se construya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingTokenProvider.notifier).set(widget.accessToken ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.accessToken ?? '';
    final feed = ref.watch(trackingControllerProvider);

    if (token.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: _NoToken(onBack: () => context.go('/orders')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: feed.when(
        loading: () => const _LoadingTracking(),
        error: (e, _) => _TrackingError(
          message: e.toString(),
          onBack: () {
            ref.invalidate(trackingControllerProvider);
            context.go('/orders');
          },
        ),
        data: (order) {
          if (order == null) {
            return const _LoadingTracking();
          }
          return OrderTrackingExperience(
            order: order,
            accessToken: token,
            onRefresh: () async {
              ref.invalidate(trackingControllerProvider);
            },
            onRatingSubmitted: (rating) {
              ref.read(trackingControllerProvider.notifier).updateRating(rating);
            },
          );
        },
      ),
    );
  }
}

class _LoadingTracking extends StatelessWidget {
  const _LoadingTracking();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _NoToken extends StatelessWidget {
  const _NoToken({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _TrackingError(
      message: 'Este enlace ya no es válido.',
      onBack: onBack,
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.link_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 22),
          PillButton(
            label: 'Volver a mis pedidos',
            icon: Symbols.receipt_long,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

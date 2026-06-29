import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/store_avatar.dart';
import '../data/payments_models.dart';
import '../data/payments_repository.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(paymentsFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: feed.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (e, _) => _PaymentsError(
              onRetry: () => ref.invalidate(paymentsFeedProvider),
            ),
            data: (payments) {
              final totalPaid =
                  payments.fold<double>(0, (sum, p) => sum + p.amount);
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Header(onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/account')),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    total: totalPaid,
                    count: payments.length,
                  ),
                  if (payments.isEmpty)
                    const _EmptyPayments()
                  else
                    _PaymentsList(payments: payments),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Symbols.arrow_back,
                    size: 20, color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mis pagos', style: AppTextStyles.h1.copyWith(fontSize: 24)),
              Text('Tu historial de pagos con todas tus tiendas.',
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 12.5, color: AppColors.ink2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.total, required this.count});
  final double total;
  final int count;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7E6), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadii.softRadius,
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2D4),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Symbols.payments,
                  color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total pagado',
                    style: AppTextStyles.subtitle
                        .copyWith(fontSize: 11.5, color: AppColors.ink3)),
                Text(money.format(total),
                    style: AppTextStyles.h2
                        .copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
            const Spacer(),
            _SummaryPill(label: '$count pagos'),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D4),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(label,
          style: AppTextStyles.chip.copyWith(
            color: const Color(0xFF8A5A0E),
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.payments});
  final List<BuyerPayment> payments;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(
        children: [
          for (final p in payments) ...[
            _PaymentRow(payment: p),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final BuyerPayment payment;
  @override
  Widget build(BuildContext context) {
    final brand = colorFromHex(payment.brandPrimaryColor);
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          StoreAvatarSm(
            label: payment.initial,
            gradientStart: lighten(brand, 0.08),
            gradientEnd: brand,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pago #${payment.paymentId}',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  '${payment.businessName} · ${_formatDate(payment.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle
                      .copyWith(fontSize: 11.5, color: AppColors.ink2),
                ),
                const SizedBox(height: 6),
                _MethodChip(method: payment.method),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(money.format(payment.amount),
              style: AppTextStyles.h2.copyWith(
                  fontSize: 17, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method});
  final String method;
  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color fg;
    Color bg;
    switch (method) {
      case 'Tarjeta':
        icon = Symbols.credit_card;
        fg = AppColors.statusRouteFg;
        bg = AppColors.statusRouteBg;
        break;
      case 'Transferencia':
      case 'Deposito':
        icon = Symbols.account_balance;
        fg = AppColors.statusPendingFg;
        bg = AppColors.statusPendingBg;
        break;
      default:
        icon = Symbols.payments;
        fg = AppColors.statusDeliveredFg;
        bg = AppColors.statusDeliveredBg;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(method,
              style: AppTextStyles.chip.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 0),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF2D4),
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            child: const Icon(Symbols.payments,
                color: AppColors.gold, size: 40),
          ),
          const SizedBox(height: 18),
          Text('Aún no tienes pagos registrados',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Cuando liquides un pedido en tienda o con tarjeta desde el link, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PaymentsError extends StatelessWidget {
  const _PaymentsError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text('No pudimos cargar tus pagos',
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Revisa tu conexión e intenta de nuevo.',
              textAlign: TextAlign.center, style: AppTextStyles.subtitle),
          const SizedBox(height: 22),
          PillButton(
              label: 'Reintentar',
              icon: Symbols.refresh,
              onPressed: onRetry),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat("d 'de' MMM, yyyy", 'es').format(date.toLocal());
}

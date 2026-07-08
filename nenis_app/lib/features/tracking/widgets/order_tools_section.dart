import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/tracking_controller.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';
import 'order_chat_sheet.dart';

/// Sección de "herramientas" de la clienta sobre el pedido: confirmar,
/// instrucciones de entrega, contacto del repartidor (chat/llamada),
/// RegiPuntos, resumen de pago (tarjeta en revisión) y evidencia de entrega.
///
/// Se inserta dentro de la experiencia V3 (`OrderTrackingExperience`) con el
/// menor impacto posible: recibe el `order` y el `accessToken` y se encarga
/// de todo lo demás.
class OrderToolsSection extends ConsumerStatefulWidget {
  const OrderToolsSection({
    super.key,
    required this.order,
    required this.accessToken,
  });

  final OrderTracking order;
  final String accessToken;

  @override
  ConsumerState<OrderToolsSection> createState() => _OrderToolsSectionState();
}

class _OrderToolsSectionState extends ConsumerState<OrderToolsSection> {
  bool _confirming = false;
  bool _editingInstructions = false;
  bool _savingInstructions = false;
  late final TextEditingController _instructionsController;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController(
      text: widget.order.deliveryInstructions ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant OrderToolsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el pedido se refresca y no estamos editando, sincronizamos el campo.
    if (!_editingInstructions &&
        widget.order.deliveryInstructions != oldWidget.order.deliveryInstructions) {
      _instructionsController.text = widget.order.deliveryInstructions ?? '';
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      widget.order.status == TrackingStatus.pending ||
      widget.order.status == TrackingStatus.postponed;

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await ref.read(trackingControllerProvider.notifier).confirmOrder();
      if (mounted) _snack('¡Pedido confirmado! 💖', tone: _Tone.success);
    } on TrackingException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('No pudimos confirmar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _saveInstructions() async {
    if (_savingInstructions) return;
    final text = _instructionsController.text.trim();
    setState(() {
      _savingInstructions = true;
    });
    try {
      await ref
          .read(trackingControllerProvider.notifier)
          .saveInstructions(text);
      if (mounted) {
        setState(() => _editingInstructions = false);
        _snack('Instrucciones guardadas ✨', tone: _Tone.success);
      }
    } on TrackingException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('No se pudieron guardar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _savingInstructions = false);
    }
  }

  void _openChat() => showOrderChatSheet(context);

  Future<void> _callCourier() async {
    final phone = widget.order.courierPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:${_normalizePhone(phone)}');
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri);
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+52$digits';
    return digits;
  }

  void _snack(String message, {_Tone tone = _Tone.error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              tone == _Tone.success ? AppColors.statusDeliveredFg : AppColors.neniDeep,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canConfirm) ...[
          _ConfirmCard(loading: _confirming, onConfirm: _confirm),
          const SizedBox(height: 16),
        ],
        _DriverContactCard(
          order: order,
          onChat: _openChat,
          onCall: _callCourier,
        ),
        const SizedBox(height: 16),
        _InstructionsCard(
          controller: _instructionsController,
          editing: _editingInstructions,
          saving: _savingInstructions,
          onEdit: () => setState(() => _editingInstructions = true),
          onCancel: () {
            _instructionsController.text = order.deliveryInstructions ?? '';
            setState(() => _editingInstructions = false);
          },
          onSave: _saveInstructions,
        ),
        const SizedBox(height: 16),
        _PointsCard(points: order.clientPoints),
        const SizedBox(height: 16),
        _PaymentCard(order: order),
        if (order.status == TrackingStatus.delivered ||
            order.status == TrackingStatus.notDelivered) ...[
          const SizedBox(height: 16),
          _EvidenceCard(order: order),
        ],
      ],
    );
  }
}

enum _Tone { success, error }

// ── Confirmar pedido ──

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({required this.loading, required this.onConfirm});
  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.neni, AppColors.neniDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Todo se ve bien? 🎀',
            style: AppTextStyles.h2.copyWith(color: AppColors.surface),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirma tu pedido para que tu tienda lo empiece a preparar.',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.surface.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.neniDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.neniDeep,
                      ),
                    )
                  : const Icon(Symbols.check_circle, size: 20),
              label: Text(
                loading ? 'Confirmando…' : 'Confirmar pedido',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.neniDeep,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Repartidor (real o neutro) + chat/llamada ──

class _DriverContactCard extends StatelessWidget {
  const _DriverContactCard({
    required this.order,
    required this.onChat,
    required this.onCall,
  });
  final OrderTracking order;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final hasCourier = (order.courierName != null && order.courierName!.isNotEmpty);
    final initial =
        hasCourier ? order.courierName!.trim().characters.first.toUpperCase() : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE1EC), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: hasCourier
                  ? const LinearGradient(
                      colors: [Color(0xFFA98CF0), Color(0xFF8E6BE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasCourier ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: hasCourier ? null : Border.all(color: AppColors.line),
            ),
            child: hasCourier
                ? Text(
                    initial.isEmpty ? '🚗' : initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : const Icon(Symbols.local_shipping, color: AppColors.neniDeep, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasCourier ? order.courierName! : 'Repartidor por asignar',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasCourier
                      ? 'Tu repartidor · ${order.driverHint}'
                      : 'Te avisamos cuando salga a entrega',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          _ContactButton(
            icon: Symbols.chat_bubble,
            onTap: onChat,
            tooltip: 'Chatear',
          ),
          if (order.courierPhone != null && order.courierPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ContactButton(
                icon: Symbols.call,
                onTap: onCall,
                tooltip: 'Llamar',
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.small,
            ),
            child: Icon(icon, size: 19, color: AppColors.neniDeep),
          ),
        ),
      ),
    );
  }
}

// ── Instrucciones de entrega (editable) ──

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({
    required this.controller,
    required this.editing,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool editing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _ToolCard(
      title: 'Instrucciones de entrega',
      icon: Symbols.navigation,
      trailing: editing
          ? null
          : GestureDetector(
              onTap: onEdit,
              child: Text(
                'Editar',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.neniDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
      child: editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.input.copyWith(fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Señas particulares de tu domicilio…',
                    hintStyle: AppTextStyles.fieldPlaceholder,
                    filled: true,
                    fillColor: AppColors.surfaceCream,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: saving ? null : onCancel,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.neni,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Text(
              controller.text.trim().isEmpty
                  ? 'Toca para agregar referencias de tu domicilio 💕'
                  : controller.text,
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                color: controller.text.trim().isEmpty
                    ? AppColors.ink3
                    : AppColors.ink,
                fontStyle: controller.text.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
    );
  }
}

// ── RegiPuntos ──

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return _ToolCard(
      title: 'RegiPuntos',
      icon: Symbols.redeem,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE6DCFF), Color(0xFFF2ECFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.stars, color: Color(0xFF7450A8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$points pts',
                  style: AppTextStyles.h2.copyWith(fontSize: 16),
                ),
                Text(
                  'Acumulas en cada compra ✨',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/points'),
            child: Text(
              'Ver mis puntos',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.neniDeep,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pago (resumen + tarjeta en revisión) ──

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );
    return _ToolCard(
      title: 'Pago',
      icon: Symbols.payments,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(label: 'Total', value: money.format(order.total)),
          _SummaryRow(
            label: 'Abonado',
            value: money.format(order.amountPaid),
            valueColor: AppColors.statusDeliveredFg,
          ),
          _SummaryRow(
            label: 'Saldo',
            value: money.format(order.balanceDue),
            valueColor: order.balanceDue > 0
                ? AppColors.neniDeep
                : AppColors.statusDeliveredFg,
            bold: true,
          ),
          if (order.payments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.lineSoft),
            const SizedBox(height: 8),
            for (final p in order.payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(_methodIcon(p.method), size: 16, color: AppColors.ink2),
                    const SizedBox(width: 8),
                    Text(
                      p.method,
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      money.format(p.amount),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (order.balanceDue > 0) ...[
            const SizedBox(height: 12),
            _CardPaymentPlaceholder(order: order),
          ],
        ],
      ),
    );
  }

  IconData _methodIcon(String method) {
    final m = method.toLowerCase();
    if (m.contains('tarjeta')) return Symbols.credit_card;
    if (m.contains('transfer')) return Symbols.account_balance;
    if (m.contains('efectivo') || m.contains('cash')) return Symbols.payments;
    return Symbols.receipt_long;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPaymentPlaceholder extends StatelessWidget {
  const _CardPaymentPlaceholder({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final hasMp = (order.mercadoPagoPublicKey != null &&
        order.mercadoPagoPublicKey!.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6DCFF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.build_circle, color: Color(0xFF7450A8), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pago con tarjeta — en revisión 🛠️',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7450A8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasMp
                      ? 'Pronto podrás pagar aquí. Por ahora paga al entregar o como acuerdes con tu tienda.'
                      : 'Esta tienda aún no habilita pago con tarjeta en la app. Paga al entregar o como acuerdes con ella.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Evidencia de entrega / no entrega ──

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.order});
  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final delivered = order.status == TrackingStatus.delivered;
    final photos = delivered ? order.evidenceUrls : order.nonDeliveryEvidenceUrls;
    if (photos.isEmpty && order.signatureSvg == null && order.failureReason == null) {
      return const SizedBox.shrink();
    }
    return _ToolCard(
      title: delivered ? 'Evidencia de entrega' : 'Evidencia del intento',
      icon: delivered ? Symbols.photo_camera : Symbols.help,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!delivered && order.failureReason != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order.failureReason!,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.neniDeep,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (photos.isNotEmpty)
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _EvidenceThumb(url: photos[i]),
              ),
            ),
          if (delivered && order.signatureSvg != null) ...[
            const SizedBox(height: 12),
            Text(
              'Firma de quien recibió',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        order.signatureSvg!,
                        style: const TextStyle(fontSize: 1, color: Colors.transparent),
                      ),
                    ),
                  ),
                  if (order.signedByName != null)
                    Text(
                      order.signedByName!,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final full = url.startsWith('http') ? url : '${_apiBase()}$url';
    return GestureDetector(
      onTap: () => _showFull(context, full),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          full,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 104,
            height: 104,
            color: AppColors.surfaceCream,
            child: const Icon(Symbols.broken_image, color: AppColors.ink3),
          ),
        ),
      ),
    );
  }

  void _showFull(BuildContext context, String src) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.network(src, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  String _apiBase() {
    // Las evidencias vienen como rutas relativas (/uploads/...) sobre la API.
    const base = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (base.isNotEmpty) return base.replaceAll(RegExp(r'/+$'), '');
    // Fallback al host del propio endpoint público (mismo origen que la API).
    return 'https://sellgeneral-api.onrender.com';
  }
}

// ── Contenedor de tarjeta reutilizable ──

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
              ),
              ?trailing,            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

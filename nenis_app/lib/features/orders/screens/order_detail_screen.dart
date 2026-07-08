import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../data/seller_order_message.dart';
import '../data/seller_orders_models.dart';
import '../data/seller_orders_repository.dart';
import '../widgets/seller_status_chip.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _amountCtrl = TextEditingController();
  final _newItemName = TextEditingController();
  final _newItemPrice = TextEditingController();
  final _newItemQty = TextEditingController(text: '1');
  bool _showAddItem = false;
  bool _busy = false;

  int get _id => widget.orderId;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _newItemName.dispose();
    _newItemPrice.dispose();
    _newItemQty.dispose();
    super.dispose();
  }

  SellerOrdersRepository get _repo => ref.read(sellerOrdersRepositoryProvider);

  void _invalidate() {
    ref.invalidate(sellerOrderDetailProvider(_id));
    ref.invalidate(sellerOrdersControllerProvider);
    ref.invalidate(sellerDashboardProvider);
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? AppColors.ink,
          content: Text(
            msg,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _invalidate();
    } catch (e) {
      _snack(e.toString(), color: const Color(0xFFE11D5B));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(SellerOrderStatus s) async {
    if (s.requiresStatusReason) {
      final draft = await showDialog<_StatusChangeDraft>(
        context: context,
        builder: (context) => _StatusChangeDialog(status: s),
      );
      if (draft == null) return;
      return _run(
        () => _repo.updateStatus(
          _id,
          s,
          postponedAt: draft.postponedAt,
          postponedNote: draft.note,
        ),
      );
    }

    return _run(() => _repo.updateStatus(_id, s));
  }

  Future<void> _setDelivery(SellerDeliveryType t) =>
      _run(() => _repo.setOrderType(_id, t));

  Future<void> _changeQty(SellerOrderItem it, int qty) => _run(() async {
    if (qty < 1) {
      await _repo.removeItem(_id, it.id);
    } else {
      await _repo.updateItem(_id, it.id, it.productName, qty, it.unitPrice);
    }
  });

  Future<void> _addItem() async {
    final name = _newItemName.text.trim();
    final price = double.tryParse(_newItemPrice.text.trim()) ?? 0;
    final qty = int.tryParse(_newItemQty.text.trim()) ?? 1;
    if (name.isEmpty || price <= 0 || qty < 1) {
      _snack('Completa nombre, precio y cantidad');
      return;
    }
    await _run(() => _repo.addItem(_id, name, qty, price));
    _newItemName.clear();
    _newItemPrice.clear();
    _newItemQty.text = '1';
    if (mounted) {
      setState(() => _showAddItem = false);
      FocusScope.of(context).unfocus();
    }
  }

  void _cancelAddItem() {
    _newItemName.clear();
    _newItemPrice.clear();
    _newItemQty.text = '1';
    setState(() => _showAddItem = false);
    FocusScope.of(context).unfocus();
  }

  Future<void> _pay(String method) async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _snack('Escribe un monto válido');
      return;
    }
    await _run(() => _repo.addPayment(_id, amount, method));
    _amountCtrl.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
      _snack(
        'Cobro de ${money(amount)} · $method registrado 💕',
        color: const Color(0xFF12A150),
      );
    }
  }

  Future<void> _copyClientMessage(SellerOrder o) async {
    final link = o.link;
    if (link == null || link.isEmpty) {
      _snack('Este pedido no tiene enlace público todavía');
      return;
    }
    await Clipboard.setData(ClipboardData(text: buildSellerOrderMessage(o)));
    _snack('Mensaje para la clienta copiado', color: const Color(0xFF7C5AC9));

    if (!o.isNotified) {
      try {
        await _repo.setNotified(o.id, true);
        _invalidate();
      } catch (_) {
        // El mensaje ya quedo copiado; esta marca no debe bloquear el flujo.
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerOrderDetailProvider(_id));

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: async.when(
            loading: () => Column(
              children: [
                _TopBar(title: 'Pedido', onBack: _goBack),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.neni),
                  ),
                ),
              ],
            ),
            error: (e, _) => Column(
              children: [
                _TopBar(title: 'Pedido', onBack: _goBack),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Symbols.cloud_off,
                            size: 44,
                            color: AppColors.ink3,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            e.toString(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            data: (o) => Column(
              children: [
                _TopBar(title: 'Detalle del pedido', onBack: _goBack),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      _DetailHead(order: o),
                      _PipelineSection(order: o, onTap: _setStatus),
                      _DeliverySection(order: o, onChange: _setDelivery),
                      _ProductsSection(
                        order: o,
                        showAddItem: _showAddItem,
                        newItemName: _newItemName,
                        newItemPrice: _newItemPrice,
                        newItemQty: _newItemQty,
                        onToggleAdd: () =>
                            setState(() => _showAddItem = !_showAddItem),
                        onAddItem: _addItem,
                        onCancelAddItem: _cancelAddItem,
                        onChangeQty: _changeQty,
                      ),
                      _PaymentsSection(
                        order: o,
                        amountCtrl: _amountCtrl,
                        onPay: _pay,
                      ),
                    ],
                  ),
                ),
                _FooterBar(order: o, onCopyLink: () => _copyClientMessage(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.adaptive.arrow_back,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(width: 38, height: 38),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

extension _StatusChangeUi on SellerOrderStatus {
  bool get requiresStatusReason =>
      this == SellerOrderStatus.postponed ||
      this == SellerOrderStatus.notDelivered ||
      this == SellerOrderStatus.canceled;

  String get dialogTitle => switch (this) {
    SellerOrderStatus.postponed => 'Reprogramar pedido',
    SellerOrderStatus.notDelivered => 'Marcar no entregado',
    SellerOrderStatus.canceled => 'Cancelar pedido',
    _ => 'Cambiar estatus',
  };

  String get noteLabel => switch (this) {
    SellerOrderStatus.postponed => 'Motivo de la reprogramacion',
    SellerOrderStatus.notDelivered => 'Motivo de no entrega',
    SellerOrderStatus.canceled => 'Motivo de cancelacion',
    _ => 'Nota',
  };
}

class _StatusChangeDraft {
  const _StatusChangeDraft({required this.note, this.postponedAt});

  final String note;
  final DateTime? postponedAt;
}

class _StatusChangeDialog extends StatefulWidget {
  const _StatusChangeDialog({required this.status});

  final SellerOrderStatus status;

  @override
  State<_StatusChangeDialog> createState() => _StatusChangeDialogState();
}

class _StatusChangeDialogState extends State<_StatusChangeDialog> {
  late final TextEditingController _noteCtrl;
  late DateTime _postponedAt;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
    final now = DateTime.now();
    _postponedAt = DateTime(now.year, now.month, now.day + 1);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _postponedAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _postponedAt = picked);
    }
  }

  void _submit() {
    setState(() => _submitted = true);
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;

    Navigator.pop(
      context,
      _StatusChangeDraft(
        note: note,
        postponedAt: widget.status == SellerOrderStatus.postponed
            ? _postponedAt
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final requiresDate = status == SellerOrderStatus.postponed;
    final noteEmpty = _submitted && _noteCtrl.text.trim().isEmpty;
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(_postponedAt);

    return AlertDialog(
      title: Text(status.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requiresDate) ...[
              Text(
                'Nueva fecha',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Symbols.event),
                label: Text(dateLabel),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _noteCtrl,
              minLines: 3,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (_) {
                if (_submitted) setState(() {});
              },
              decoration: InputDecoration(
                labelText: status.noteLabel,
                hintText: 'Escribe una nota clara para el historial.',
                errorText: noteEmpty ? 'La nota es obligatoria.' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(status.label)),
      ],
    );
  }
}

class _DetailHead extends StatelessWidget {
  const _DetailHead({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEAF1), Color(0xFFF3EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FE84E83)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📦', style: TextStyle(fontSize: 19)),
                  const SizedBox(width: 8),
                  Text(
                    'Pedido #${o.id}',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SellerStatusChip(status: o.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FE84E83)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.neni, AppColors.neniDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    o.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.clientName.isEmpty ? 'Sin nombre' : o.clientName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          if ((o.clientPhone ?? '').isNotEmpty) o.clientPhone!,
                          if (o.isFrequent) 'Frecuente',
                        ].join(' · '),
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (o.clientPoints > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${o.clientPoints} pts',
                      style: const TextStyle(
                        color: Color(0xFF7C5AC9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.neniDeep),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: AppColors.neniDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PipelineSection extends StatelessWidget {
  const _PipelineSection({required this.order, required this.onTap});
  final SellerOrder order;
  final ValueChanged<SellerOrderStatus> onTap;

  static const _flow = [
    SellerOrderStatus.pending,
    SellerOrderStatus.confirmed,
    SellerOrderStatus.shipped,
    SellerOrderStatus.inRoute,
    SellerOrderStatus.delivered,
    SellerOrderStatus.postponed,
    SellerOrderStatus.notDelivered,
    SellerOrderStatus.canceled,
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Symbols.timeline,
      title: 'Estatus del pedido',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _flow.length; i++) ...[
              _PipeStep(
                status: _flow[i],
                active: order.status == _flow[i],
                onTap: () => onTap(_flow[i]),
              ),
              if (i < _flow.length - 1)
                Container(width: 14, height: 2, color: const Color(0x33FB6F9C)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PipeStep extends StatelessWidget {
  const _PipeStep({
    required this.status,
    required this.active,
    required this.onTap,
  });
  final SellerOrderStatus status;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? status.bg : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? Colors.transparent : AppColors.line,
          ),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? status.fg : AppColors.ink3,
          ),
        ),
      ),
    );
  }
}

class _DeliverySection extends StatelessWidget {
  const _DeliverySection({required this.order, required this.onChange});
  final SellerOrder order;
  final ValueChanged<SellerDeliveryType> onChange;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return _Section(
      icon: Symbols.local_shipping,
      title: 'Entrega',
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0x0D3A2233),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _ToggleBtn(
                    label: '🛵 Domicilio',
                    active: o.orderType == SellerDeliveryType.delivery,
                    onTap: () => onChange(SellerDeliveryType.delivery),
                  ),
                  _ToggleBtn(
                    label: '🛍️ Recoger',
                    active: o.orderType == SellerDeliveryType.pickup,
                    onTap: () => onChange(SellerDeliveryType.pickup),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.local_shipping,
                  size: 16,
                  color: AppColors.neni,
                ),
                const SizedBox(width: 6),
                Text(
                  'Envío ${money(o.shippingCost)}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active ? AppShadows.small : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.neniDeep : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({
    required this.order,
    required this.showAddItem,
    required this.newItemName,
    required this.newItemPrice,
    required this.newItemQty,
    required this.onToggleAdd,
    required this.onAddItem,
    required this.onCancelAddItem,
    required this.onChangeQty,
  });

  final SellerOrder order;
  final bool showAddItem;
  final TextEditingController newItemName;
  final TextEditingController newItemPrice;
  final TextEditingController newItemQty;
  final VoidCallback onToggleAdd;
  final VoidCallback onAddItem;
  final VoidCallback onCancelAddItem;
  final void Function(SellerOrderItem item, int qty) onChangeQty;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return _Section(
      icon: Symbols.shopping_bag,
      title: 'Productos (${o.items.length})',
      child: Column(
        children: [
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF0F5), Color(0xFFF3EBFF)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.checkroom,
                      size: 20,
                      color: AppColors.neniDeep,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _Stepper(
                          qty: it.quantity,
                          onMinus: () => onChangeQty(it, it.quantity - 1),
                          onPlus: () => onChangeQty(it, it.quantity + 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(it.lineTotal),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neniDeep,
                        ),
                      ),
                      Text(
                        '${money(it.unitPrice)} c/u',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (showAddItem)
            _AddItemForm(
              name: newItemName,
              price: newItemPrice,
              qty: newItemQty,
              onAdd: onAddItem,
              onCancel: onCancelAddItem,
            )
          else
            GestureDetector(
              onTap: onToggleAdd,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x99FFF0F5), Color(0x66F3EBFF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0x4DE84E83),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Symbols.add_circle,
                      size: 18,
                      color: AppColors.neniDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Agregar artículo',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neniDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: Icon(Symbols.remove, size: 16, color: AppColors.neniDeep),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          InkWell(
            onTap: onPlus,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: Icon(Symbols.add, size: 16, color: AppColors.neniDeep),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItemForm extends StatelessWidget {
  const _AddItemForm({
    required this.name,
    required this.price,
    required this.qty,
    required this.onAdd,
    required this.onCancel,
  });
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController qty;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x99FFF0F5), Color(0x66F3EBFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4DE84E83), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Symbols.add_circle,
                size: 18,
                color: AppColors.neniDeep,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Agregar artículo',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neniDeep,
                  ),
                ),
              ),
              _CancelMiniButton(onTap: onCancel),
            ],
          ),
          const SizedBox(height: 9),
          _MiniField(controller: name, hint: 'Nombre del producto'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  controller: price,
                  hint: '\$ Precio',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: _MiniField(
                  controller: qty,
                  hint: 'Cant.',
                  center: true,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(11),
                  child: Ink(
                    height: 42,
                    width: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.neni, AppColors.neniDeep],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        'OK',
                        style: AppTextStyles.button.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelMiniButton extends StatelessWidget {
  const _CancelMiniButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.close, size: 15, color: AppColors.ink2),
              const SizedBox(width: 4),
              Text(
                'Cancelar',
                style: AppTextStyles.body.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.center = false,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: AppTextStyles.body.copyWith(fontSize: 12.5),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 12.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.neni, width: 1.2),
        ),
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({
    required this.order,
    required this.amountCtrl,
    required this.onPay,
  });
  final SellerOrder order;
  final TextEditingController amountCtrl;
  final ValueChanged<String> onPay;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return _Section(
      icon: Symbols.payments,
      title: 'Cobros express',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F4),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x24E11D5B)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RESTANTE ',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE11D5B).withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    money(o.balanceDue),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE11D5B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    color: AppColors.neniDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Monto a cobrar',
                      hintStyle: AppTextStyles.fieldPlaceholder.copyWith(
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MethodButton(
                emoji: '💵',
                label: 'Efectivo',
                onTap: () => onPay('Efectivo'),
              ),
              const SizedBox(width: 9),
              _MethodButton(
                emoji: '🏦',
                label: 'Transf.',
                onTap: () => onPay('Transferencia'),
              ),
              const SizedBox(width: 9),
              _MethodButton(
                emoji: '💳',
                label: 'Tarjeta',
                onTap: () => onPay('Tarjeta'),
              ),
            ],
          ),
          if (o.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 10),
            Text(
              'HISTORIAL DE PAGOS',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 6),
            for (final p in o.payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.method,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.ink2,
                      ),
                    ),
                    Text(
                      money(p.amount),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
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

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 19)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.order, required this.onCopyLink});
  final SellerOrder order;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.ink3,
                ),
              ),
              Text(
                money(order.total),
                style: AppTextStyles.h1.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neniDeep,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCopyLink,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E9FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.link,
                      size: 19,
                      color: Color(0xFF7C5AC9),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Copiar mensaje',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C5AC9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

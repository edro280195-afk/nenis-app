import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../data/seller_orders_data.dart';
import '../widgets/seller_status_chip.dart';
import 'seller_orders_screen.dart' show GradientText;

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  final _amountCtrl = TextEditingController();
  final _newItemName = TextEditingController();
  final _newItemPrice = TextEditingController();
  final _newItemQty = TextEditingController(text: '1');
  bool _showAddItem = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _newItemName.dispose();
    _newItemPrice.dispose();
    _newItemQty.dispose();
    super.dispose();
  }

  SellerOrdersNotifier get _notifier =>
      ref.read(sellerOrdersProvider.notifier);

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.ink,
        content:
            Text(msg, style: AppTextStyles.body.copyWith(color: Colors.white)),
      ));
  }

  void _addPayment(String orderId, String method) {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _snack('Escribe un monto válido');
      return;
    }
    _notifier.addPayment(orderId, amount, method);
    _amountCtrl.clear();
    FocusScope.of(context).unfocus();
    _snack('Cobro de ${money(amount)} · $method registrado 💕',
        color: const Color(0xFF12A150));
  }

  void _addItem(String orderId) {
    final name = _newItemName.text.trim();
    final price = double.tryParse(_newItemPrice.text.trim()) ?? 0;
    final qty = int.tryParse(_newItemQty.text.trim()) ?? 1;
    if (name.isEmpty || price <= 0 || qty < 1) {
      _snack('Completa nombre, precio y cantidad');
      return;
    }
    _notifier.addItem(orderId, name, qty, price);
    _newItemName.clear();
    _newItemPrice.clear();
    _newItemQty.text = '1';
    setState(() => _showAddItem = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(sellerOrdersProvider);
    SellerOrder? order;
    for (final o in orders) {
      if (o.id == widget.orderId) {
        order = o;
        break;
      }
    }

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCream,
        body: NeniBackground(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(title: 'Pedido', onClose: () => context.pop()),
                const Spacer(),
                const Icon(Symbols.receipt_long,
                    size: 46, color: AppColors.ink3),
                const SizedBox(height: 12),
                Text('Este pedido ya no existe',
                    style: AppTextStyles.h2.copyWith(fontSize: 17)),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    final o = order;
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                title: 'Detalle del pedido',
                onClose: () => context.pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    _DetailHead(order: o),
                    _PipelineSection(order: o),
                    _DeliverySection(order: o),
                    _ProductsSection(
                      order: o,
                      showAddItem: _showAddItem,
                      newItemName: _newItemName,
                      newItemPrice: _newItemPrice,
                      newItemQty: _newItemQty,
                      onToggleAdd: () =>
                          setState(() => _showAddItem = !_showAddItem),
                      onAddItem: () => _addItem(o.id),
                    ),
                    _PaymentsSection(
                      order: o,
                      amountCtrl: _amountCtrl,
                      onPay: (method) => _addPayment(o.id, method),
                    ),
                    const _PointsSection(),
                  ],
                ),
              ),
              _FooterBar(
                order: o,
                onAction: (label) => _snack('$label · disponible al conectar backend'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          _RoundButton(icon: Symbols.arrow_back_ios_new, onTap: onClose),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(fontSize: 15)),
          ),
          _RoundButton(icon: Symbols.close, onTap: onClose),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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
                  Text('Pedido #${o.id}',
                      style: AppTextStyles.h2
                          .copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  child: Text(o.initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.clientName,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${o.clientPhone}${o.isFrequent ? ' · Frecuente' : ''}',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Symbols.edit, size: 15, color: AppColors.ink3),
                const SizedBox(width: 3),
                Text('Editar',
                    style: AppTextStyles.subtitle.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child, this.iconColor});
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

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
              Icon(icon, size: 16, color: iconColor ?? AppColors.neniDeep),
              const SizedBox(width: 6),
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: iconColor ?? AppColors.neniDeep)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PipelineSection extends ConsumerWidget {
  const _PipelineSection({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const steps = SellerOrderStatus.values;
    return _Section(
      icon: Symbols.timeline,
      title: 'Estatus del pedido',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _PipeStep(
                status: steps[i],
                active: order.status == steps[i],
                onTap: () => ref
                    .read(sellerOrdersProvider.notifier)
                    .updateStatus(order.id, steps[i]),
              ),
              if (i < steps.length - 1)
                Container(
                  width: 14,
                  height: 2,
                  color: const Color(0x33FB6F9C),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PipeStep extends StatelessWidget {
  const _PipeStep(
      {required this.status, required this.active, required this.onTap});
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
              color: active ? Colors.transparent : AppColors.line),
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

class _DeliverySection extends ConsumerWidget {
  const _DeliverySection({required this.order});
  final SellerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final notifier = ref.read(sellerOrdersProvider.notifier);
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
                    active: o.deliveryType == SellerDeliveryType.delivery,
                    onTap: () => notifier.setDeliveryType(
                        o.id, SellerDeliveryType.delivery),
                  ),
                  _ToggleBtn(
                    label: '🛍️ Recoger',
                    active: o.deliveryType == SellerDeliveryType.pickup,
                    onTap: () => notifier.setDeliveryType(
                        o.id, SellerDeliveryType.pickup),
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
                const Icon(Symbols.event, size: 17, color: AppColors.neni),
                const SizedBox(width: 6),
                Text('Envío ${money(o.shippingCost)}',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});
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
          child: Text(label,
              style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.neniDeep : AppColors.ink2)),
        ),
      ),
    );
  }
}

class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({
    required this.order,
    required this.showAddItem,
    required this.newItemName,
    required this.newItemPrice,
    required this.newItemQty,
    required this.onToggleAdd,
    required this.onAddItem,
  });

  final SellerOrder order;
  final bool showAddItem;
  final TextEditingController newItemName;
  final TextEditingController newItemPrice;
  final TextEditingController newItemQty;
  final VoidCallback onToggleAdd;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final notifier = ref.read(sellerOrdersProvider.notifier);
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
                    child: const Icon(Symbols.checkroom,
                        size: 20, color: AppColors.neniDeep),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        _Stepper(
                          qty: it.qty,
                          onMinus: () => it.qty > 1
                              ? notifier.changeItemQty(o.id, it.id, it.qty - 1)
                              : notifier.removeItem(o.id, it.id),
                          onPlus: () =>
                              notifier.changeItemQty(o.id, it.id, it.qty + 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(it.lineTotal),
                          style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neniDeep)),
                      Text('${money(it.unitPrice)} c/u',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 11)),
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
                      style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.add_circle,
                        size: 18, color: AppColors.neniDeep),
                    const SizedBox(width: 6),
                    Text('Agregar artículo',
                        style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neniDeep)),
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
  const _Stepper(
      {required this.qty, required this.onMinus, required this.onPlus});
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
          _StepBtn(icon: Symbols.remove, onTap: onMinus),
          SizedBox(
            width: 26,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          _StepBtn(icon: Symbols.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(icon, size: 16, color: AppColors.neniDeep),
      ),
    );
  }
}

class _AddItemForm extends StatelessWidget {
  const _AddItemForm(
      {required this.name,
      required this.price,
      required this.qty,
      required this.onAdd});
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController qty;
  final VoidCallback onAdd;

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
          _MiniField(controller: name, hint: 'Nombre del producto'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniField(
                    controller: price,
                    hint: '\$ Precio',
                    keyboard: TextInputType.number),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: _MiniField(
                    controller: qty,
                    hint: 'Cant.',
                    center: true,
                    keyboard: TextInputType.number),
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
                      child: Text('OK',
                          style: AppTextStyles.button.copyWith(fontSize: 12)),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                  Text('RESTANTE ',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE11D5B).withValues(alpha: 0.8))),
                  Text(money(o.balanceDue),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE11D5B))),
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
                const Text('\$',
                    style: TextStyle(
                        color: AppColors.neniDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    style: AppTextStyles.body.copyWith(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Monto a cobrar',
                      hintStyle:
                          AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13),
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
              _MethodButton(emoji: '💵', label: 'Efectivo', onTap: () => onPay('Efectivo')),
              const SizedBox(width: 9),
              _MethodButton(emoji: '🏦', label: 'Transf.', onTap: () => onPay('Transferencia')),
              const SizedBox(width: 9),
              _MethodButton(emoji: '💳', label: 'Tarjeta', onTap: () => onPay('Tarjeta')),
            ],
          ),
          if (o.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 10),
            Text('HISTORIAL DE PAGOS',
                style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.ink3)),
            const SizedBox(height: 6),
            for (final p in o.payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p.method,
                        style: AppTextStyles.body.copyWith(
                            fontSize: 12, color: AppColors.ink2)),
                    Text(money(p.amount),
                        style: AppTextStyles.body.copyWith(
                            fontSize: 12.5, fontWeight: FontWeight.w800)),
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
  const _MethodButton(
      {required this.emoji, required this.label, required this.onTap});
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
                Text(label,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsSection extends StatelessWidget {
  const _PointsSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Symbols.diamond,
      title: 'Canjear puntos',
      iconColor: AppColors.lavender,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Text('🎁', style: TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Envío gratis',
                    style: AppTextStyles.body
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Descuento de \$60 · saldo 340 pts',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.lavender, AppColors.neniDeep],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('200 pts',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.order, required this.onAction});
  final SellerOrder order;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
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
              Text('TOTAL',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.ink3)),
              GradientText(money(order.total), fontSize: 20),
            ],
          ),
          Row(
            children: [
              _FooterAction(
                  icon: Symbols.link,
                  fg: const Color(0xFF7C5AC9),
                  bg: const Color(0xFFF1E9FF),
                  onTap: () => onAction('Copiar enlace')),
              const SizedBox(width: 8),
              _FooterAction(
                  icon: Symbols.chat,
                  fg: const Color(0xFF12A150),
                  bg: const Color(0xFFE9F9EE),
                  onTap: () => onAction('WhatsApp')),
              const SizedBox(width: 8),
              _FooterAction(
                  icon: Symbols.directions_car,
                  fg: const Color(0xFF2E6BD6),
                  bg: const Color(0xFFE4ECFF),
                  onTap: () => onAction('En camino')),
              const SizedBox(width: 8),
              _FooterAction(
                  icon: Symbols.request_quote,
                  fg: const Color(0xFFE11D5B),
                  bg: const Color(0xFFFFF1F4),
                  onTap: () => onAction('Cobrar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction(
      {required this.icon,
      required this.fg,
      required this.bg,
      required this.onTap});
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, size: 19, color: fg),
        ),
      ),
    );
  }
}

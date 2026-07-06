import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../data/seller_orders_data.dart';
import 'seller_orders_screen.dart' show GradientText;

class _Draft {
  _Draft(this.name, this.qty, this.price);
  String name;
  int qty;
  double price;
  double get lineTotal => qty * price;
}

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _itemName = TextEditingController();
  final _itemPrice = TextEditingController();
  final _itemQty = TextEditingController(text: '1');

  bool _isFrequent = false;
  bool _picked = false;
  SellerDeliveryType _delivery = SellerDeliveryType.delivery;
  final List<_Draft> _items = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _itemName.dispose();
    _itemPrice.dispose();
    _itemQty.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.lineTotal);
  double get _shipping => _delivery == SellerDeliveryType.pickup ? 0 : 60;
  double get _total => _subtotal + _shipping;

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

  void _addDraftItem() {
    final name = _itemName.text.trim();
    final price = double.tryParse(_itemPrice.text.trim()) ?? 0;
    final qty = int.tryParse(_itemQty.text.trim()) ?? 1;
    if (name.isEmpty || price <= 0 || qty < 1) {
      _snack('Completa nombre, precio y cantidad');
      return;
    }
    setState(() {
      _items.add(_Draft(name, qty, price));
      _itemName.clear();
      _itemPrice.clear();
      _itemQty.text = '1';
    });
    FocusScope.of(context).unfocus();
  }

  void _create() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Escribe el nombre de la clienta');
      return;
    }
    if (_items.isEmpty) {
      _snack('Agrega al menos un artículo');
      return;
    }
    final notifier = ref.read(sellerOrdersProvider.notifier);
    final folio = notifier.nextFolio();
    final items = _items
        .map((d) => notifier.newItem(d.name, d.qty, d.price))
        .toList();
    notifier.addOrder(SellerOrder(
      id: folio,
      clientName: name,
      clientPhone: _phoneCtrl.text.trim(),
      isFrequent: _isFrequent,
      status: SellerOrderStatus.pending,
      deliveryType: _delivery,
      address: _delivery == SellerDeliveryType.pickup ? 'Recoge en tienda' : '',
      createdAt: DateTime.now(),
      shippingCost: _shipping,
      items: items,
    ));
    _snack('Pedido #$folio creado ✨', color: const Color(0xFF12A150));
    context.pop();
  }

  List<SellerOrder> _suggestions() {
    final q = _nameCtrl.text.trim().toLowerCase();
    if (q.isEmpty || _picked) return const [];
    final seen = <String>{};
    final result = <SellerOrder>[];
    for (final o in ref.read(sellerOrdersProvider)) {
      final key = o.clientName.toLowerCase();
      if (key == q) continue;
      if (key.contains(q) && seen.add(key)) result.add(o);
      if (result.length >= 3) break;
    }
    return result;
  }

  void _pickClient(SellerOrder o) {
    setState(() {
      _nameCtrl.text = o.clientName;
      _phoneCtrl.text = o.clientPhone;
      _isFrequent = o.isFrequent;
      _picked = true;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions();
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  children: [
                    _SectionCard(
                      icon: Symbols.person_search,
                      title: 'Clienta',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field(
                            controller: _nameCtrl,
                            hint: 'Buscar o crear clienta',
                            icon: Symbols.search,
                            onChanged: (_) => setState(() => _picked = false),
                          ),
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _SuggestionList(
                              suggestions: suggestions,
                              onPick: _pickClient,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _phoneCtrl,
                                  hint: 'Teléfono',
                                  icon: Symbols.call,
                                  keyboard: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _FrequentToggle(
                                value: _isFrequent,
                                onTap: () => setState(
                                    () => _isFrequent = !_isFrequent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _SectionCard(
                      icon: Symbols.shopping_bag,
                      title: 'Artículos (${_items.length})',
                      child: Column(
                        children: [
                          for (var i = 0; i < _items.length; i++)
                            _DraftRow(
                              item: _items[i],
                              onMinus: () => setState(() {
                                if (_items[i].qty > 1) {
                                  _items[i].qty--;
                                } else {
                                  _items.removeAt(i);
                                }
                              }),
                              onPlus: () => setState(() => _items[i].qty++),
                              onRemove: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                          _AddItemForm(
                            name: _itemName,
                            price: _itemPrice,
                            qty: _itemQty,
                            onAdd: _addDraftItem,
                          ),
                        ],
                      ),
                    ),
                    _SectionCard(
                      icon: Symbols.local_shipping,
                      title: 'Entrega',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0x0D3A2233),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _ToggleBtn(
                              label: '🛵 A domicilio',
                              active: _delivery == SellerDeliveryType.delivery,
                              onTap: () => setState(() =>
                                  _delivery = SellerDeliveryType.delivery),
                            ),
                            _ToggleBtn(
                              label: '🛍️ Recoger',
                              active: _delivery == SellerDeliveryType.pickup,
                              onTap: () => setState(
                                  () => _delivery = SellerDeliveryType.pickup),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SectionCard(
                      icon: Symbols.receipt,
                      title: 'Resumen',
                      child: Column(
                        children: [
                          _SumLine(label: 'Subtotal', value: money(_subtotal)),
                          _SumLine(label: 'Envío', value: money(_shipping)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.only(top: 11),
                            decoration: const BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: AppColors.line)),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: AppColors.ink3)),
                                GradientText(money(_total), fontSize: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CreateButton(onTap: _create),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Symbols.arrow_back_ios_new,
                    size: 20, color: AppColors.ink),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.h2.copyWith(fontSize: 16),
                  children: [
                    const TextSpan(text: 'Nuevo '),
                    TextSpan(
                      text: 'pedido',
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 16,
                        color: AppColors.neniDeep,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.icon, required this.title, required this.child});
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
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: AppColors.neniDeep)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: AppTextStyles.body.copyWith(fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: Icon(icon, size: 19, color: AppColors.ink3),
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neni, width: 1.2),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onPick});
  final List<SellerOrder> suggestions;
  final ValueChanged<SellerOrder> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++)
            _SuggestionTile(
              order: suggestions[i],
              isLast: i == suggestions.length - 1,
              onTap: () => onPick(suggestions[i]),
            ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile(
      {required this.order, required this.isLast, required this.onTap});
  final SellerOrder order;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.neni, AppColors.neniDeep],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(order.initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.clientName,
                      style: AppTextStyles.body.copyWith(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    '${order.clientPhone}${order.isFrequent ? ' · Frecuente' : ''}',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Symbols.north_west, size: 16, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}

class _FrequentToggle extends StatelessWidget {
  const _FrequentToggle({required this.value, required this.onTap});
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFF1E9FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: value ? const Color(0x339B7BE0) : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(value ? Symbols.favorite : Symbols.favorite,
                size: 17,
                fill: value ? 1 : 0,
                color: value ? const Color(0xFF7C5AC9) : AppColors.ink3),
            const SizedBox(width: 6),
            Text('Frecuente',
                style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value ? const Color(0xFF7C5AC9) : AppColors.ink2)),
          ],
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow(
      {required this.item,
      required this.onMinus,
      required this.onPlus,
      required this.onRemove});
  final _Draft item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _Stepper(qty: item.qty, onMinus: onMinus, onPlus: onPlus),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(money(item.lineTotal),
              style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neniDeep)),
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
          InkWell(
            onTap: onMinus,
            child: const SizedBox(
                width: 26,
                height: 26,
                child: Icon(Symbols.remove, size: 16, color: AppColors.neniDeep)),
          ),
          SizedBox(
            width: 26,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: AppTextStyles.body
                    .copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          InkWell(
            onTap: onPlus,
            child: const SizedBox(
                width: 26,
                height: 26,
                child: Icon(Symbols.add, size: 16, color: AppColors.neniDeep)),
          ),
        ],
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
          Row(
            children: [
              const Icon(Symbols.add_circle, size: 18, color: AppColors.neniDeep),
              const SizedBox(width: 6),
              Text('Agregar artículo',
                  style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neniDeep)),
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
          height: 40,
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

class _SumLine extends StatelessWidget {
  const _SumLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.subtitle
                  .copyWith(fontSize: 12.5, color: AppColors.ink2)),
          Text(value,
              style: AppTextStyles.body
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.auto_awesome, size: 21, color: Colors.white),
              const SizedBox(width: 8),
              Text('Crear pedido',
                  style: AppTextStyles.button.copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

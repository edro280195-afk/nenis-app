import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../data/seller_order_capture_parser.dart';
import '../data/seller_order_message.dart';
import '../data/seller_orders_models.dart';
import '../data/seller_orders_repository.dart';
import 'seller_orders_screen.dart' show GradientText;

enum _CaptureMode { quick, manual }

class _CaptureWorkspace {
  const _CaptureWorkspace({required this.clients, required this.products});
  final List<SellerClient> clients;
  final List<CommonProduct> products;
}

final _captureWorkspaceProvider = FutureProvider.autoDispose<_CaptureWorkspace>(
  (ref) async {
    final repo = ref.read(sellerOrdersRepositoryProvider);
    final clients = await repo.getClients();
    final products = await repo.getCommonProducts();
    return _CaptureWorkspace(clients: clients, products: products);
  },
);

class _QuickQueueItem {
  _QuickQueueItem({
    required this.id,
    required this.clientName,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.clientId,
    this.isExistingClient = false,
  });

  final String id;
  String clientName;
  String productName;
  int quantity;
  double unitPrice;
  int? clientId;
  bool isExistingClient;

  double get lineTotal => quantity * unitPrice;
}

class _QueueGroup {
  const _QueueGroup({
    required this.key,
    required this.clientName,
    required this.items,
  });

  final String key;
  final String clientName;
  final List<_QuickQueueItem> items;

  double get total => items.fold(0, (sum, item) => sum + item.lineTotal);
  int? get clientId =>
      items.where((i) => i.clientId != null).firstOrNull?.clientId;
}

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _manualClientCtrl = TextEditingController();
  final _manualPhoneCtrl = TextEditingController();
  final _manualAddressCtrl = TextEditingController();
  final _manualInstructionsCtrl = TextEditingController();
  final _manualItemNameCtrl = TextEditingController();
  final _manualItemPriceCtrl = TextEditingController();
  final _manualItemQtyCtrl = TextEditingController(text: '1');
  final _quickInputCtrl = TextEditingController();
  final _pinNameCtrl = TextEditingController();
  final _pinPriceCtrl = TextEditingController();

  final _manualClientFocus = FocusNode();
  final _manualProductFocus = FocusNode();
  final _quickFocus = FocusNode();

  _CaptureMode _mode = _CaptureMode.quick;
  SellerDeliveryType _manualDelivery = SellerDeliveryType.delivery;
  SellerDeliveryType _quickDelivery = SellerDeliveryType.delivery;
  SellerClient? _manualClient;
  bool _manualFrequent = false;
  bool _manualAddressOnlyForOrder = false;
  DateTime? _manualScheduledDate;
  bool _creatingManual = false;
  bool _submittingQuick = false;
  String? _quickProgress;
  CommonProduct? _pinnedProduct;
  final List<DraftOrderItem> _manualItems = [];
  final List<_QuickQueueItem> _quickQueue = [];
  final List<SellerOrder> _createdOrders = [];

  @override
  void dispose() {
    _manualClientCtrl.dispose();
    _manualPhoneCtrl.dispose();
    _manualAddressCtrl.dispose();
    _manualInstructionsCtrl.dispose();
    _manualItemNameCtrl.dispose();
    _manualItemPriceCtrl.dispose();
    _manualItemQtyCtrl.dispose();
    _quickInputCtrl.dispose();
    _pinNameCtrl.dispose();
    _pinPriceCtrl.dispose();
    _manualClientFocus.dispose();
    _manualProductFocus.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  double get _manualSubtotal => _manualItems.fold(0, (s, i) => s + i.lineTotal);
  double get _manualShipping =>
      _manualDelivery == SellerDeliveryType.pickup ? 0 : 60;
  double get _manualTotal => _manualSubtotal + _manualShipping;
  double get _quickTotal => _quickQueue.fold(0, (s, i) => s + i.lineTotal);

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

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(_captureWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(onBack: _goBack),
              Expanded(
                child: workspaceAsync.when(
                  loading: () => const _CaptureLoading(),
                  error: (error, _) => _CaptureError(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(_captureWorkspaceProvider),
                  ),
                  data: (workspace) => ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                    children: [
                      _ModeSwitch(
                        mode: _mode,
                        onChanged: (mode) => setState(() => _mode = mode),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _mode == _CaptureMode.quick
                            ? _buildQuickMode(workspace)
                            : _buildManualMode(workspace),
                      ),
                      if (_createdOrders.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CreatedOrdersPanel(
                          orders: _createdOrders,
                          onCopyAll: _copyCreatedMessages,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMode(_CaptureWorkspace workspace) {
    final suggestions = _quickClientSuggestions(workspace.clients);
    final groups = _queueGroups();
    return Column(
      key: const ValueKey('quick-capture'),
      children: [
        _QuickHero(
          input: _quickInputCtrl,
          focusNode: _quickFocus,
          delivery: _quickDelivery,
          pinnedProduct: _pinnedProduct,
          submitting: _submittingQuick,
          progress: _quickProgress,
          onDeliveryChanged: (delivery) =>
              setState(() => _quickDelivery = delivery),
          onSubmitted: (_) => _addQuickEntry(workspace.clients),
          onChanged: (_) => setState(() {}),
          onClearPin: () => setState(() => _pinnedProduct = null),
        ),
        if (suggestions.isNotEmpty)
          _ClientSuggestions(
            clients: suggestions,
            onPick: (client) => _pickQuickClient(client),
          ),
        const SizedBox(height: 12),
        _PinProductCard(
          name: _pinNameCtrl,
          price: _pinPriceCtrl,
          pinned: _pinnedProduct,
          products: workspace.products,
          onPin: _pinProduct,
          onPickProduct: (product) {
            _pinNameCtrl.text = product.name;
            _pinPriceCtrl.text = _cleanMoney(product.typicalPrice);
            _pinProduct();
          },
          onClear: () => setState(() => _pinnedProduct = null),
        ),
        const SizedBox(height: 12),
        _QuickQueuePanel(
          groups: groups,
          total: _quickTotal,
          submitting: _submittingQuick,
          onSubmit: groups.isEmpty
              ? null
              : () => _submitQuickQueue(workspace.clients),
          onRemove: (id) =>
              setState(() => _quickQueue.removeWhere((i) => i.id == id)),
          onQuantityChanged: (item, quantity) {
            setState(() {
              if (quantity < 1) {
                _quickQueue.remove(item);
              } else {
                item.quantity = quantity;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildManualMode(_CaptureWorkspace workspace) {
    final clientSuggestions = _manualClientSuggestions(workspace.clients);
    final productSuggestions = _productSuggestions(workspace.products);
    return Column(
      key: const ValueKey('manual-capture'),
      children: [
        _SectionCard(
          icon: Symbols.person,
          title: 'Clienta',
          child: Column(
            children: [
              _Field(
                controller: _manualClientCtrl,
                focusNode: _manualClientFocus,
                hint: 'Nombre de la clienta',
                icon: Symbols.badge,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _onManualClientChanged(workspace.clients),
              ),
              if (clientSuggestions.isNotEmpty)
                _ClientSuggestions(
                  clients: clientSuggestions,
                  onPick: (client) => _selectManualClient(client),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _manualPhoneCtrl,
                      hint: 'Telefono opcional',
                      icon: Symbols.call,
                      keyboard: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FrequentToggle(
                    value: _manualFrequent,
                    locked: _manualClient != null,
                    onTap: _manualClient == null
                        ? () =>
                              setState(() => _manualFrequent = !_manualFrequent)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        _SectionCard(
          icon: Symbols.local_shipping,
          title: 'Entrega',
          child: Column(
            children: [
              _DeliveryToggle(
                value: _manualDelivery,
                onChanged: (value) => setState(() => _manualDelivery = value),
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _manualAddressCtrl,
                hint: _manualDelivery == SellerDeliveryType.pickup
                    ? 'Direccion opcional'
                    : 'Direccion de entrega',
                icon: Symbols.location_on,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              _InlineToggle(
                value: _manualAddressOnlyForOrder,
                label: 'Usar direccion solo para este pedido',
                onChanged: (value) =>
                    setState(() => _manualAddressOnlyForOrder = value),
              ),
              const SizedBox(height: 8),
              _Field(
                controller: _manualInstructionsCtrl,
                hint: 'Indicaciones de entrega opcionales',
                icon: Symbols.notes,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _DateRow(
                date: _manualScheduledDate,
                onPick: _pickScheduledDate,
                onClear: _manualScheduledDate == null
                    ? null
                    : () => setState(() => _manualScheduledDate = null),
                onNextSunday: () =>
                    setState(() => _manualScheduledDate = _nextSunday()),
              ),
            ],
          ),
        ),
        _SectionCard(
          icon: Symbols.shopping_bag,
          title: 'Articulos (${_manualItems.length})',
          child: Column(
            children: [
              _ManualAddItemForm(
                name: _manualItemNameCtrl,
                price: _manualItemPriceCtrl,
                qty: _manualItemQtyCtrl,
                focusNode: _manualProductFocus,
                suggestions: productSuggestions,
                onPickProduct: _pickManualProduct,
                onAdd: _addManualItem,
                onCancel: _cancelManualItem,
              ),
              const SizedBox(height: 10),
              _ManualItemsList(
                items: _manualItems,
                onRemove: (item) => setState(() => _manualItems.remove(item)),
                onQuantityChanged: (item, quantity) {
                  setState(() {
                    if (quantity < 1) {
                      _manualItems.remove(item);
                    } else {
                      item.quantity = quantity;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        _ManualSummary(
          subtotal: _manualSubtotal,
          shipping: _manualShipping,
          total: _manualTotal,
          creating: _creatingManual,
          canCreate:
              _manualItems.isNotEmpty &&
              _manualClientCtrl.text.trim().isNotEmpty,
          onCreate: _createManualOrder,
        ),
      ],
    );
  }

  List<SellerClient> _manualClientSuggestions(List<SellerClient> clients) {
    final query = normalizeCaptureText(_manualClientCtrl.text);
    if (query.isEmpty) return const [];
    return clients
        .where((client) => normalizeCaptureText(client.name).contains(query))
        .take(6)
        .toList();
  }

  List<SellerClient> _quickClientSuggestions(List<SellerClient> clients) {
    final query = normalizeCaptureText(_quickSearchTerm());
    if (query.isEmpty) return const [];
    return clients
        .where((client) => normalizeCaptureText(client.name).contains(query))
        .take(6)
        .toList();
  }

  List<CommonProduct> _productSuggestions(List<CommonProduct> products) {
    final query = normalizeCaptureText(_manualItemNameCtrl.text);
    if (query.isEmpty) return products.take(6).toList();
    return products
        .where((p) => normalizeCaptureText(p.name).contains(query))
        .take(6)
        .toList();
  }

  void _onManualClientChanged(List<SellerClient> clients) {
    final typed = normalizeCaptureText(_manualClientCtrl.text);
    final exact = clients
        .where((c) => normalizeCaptureText(c.name) == typed)
        .firstOrNull;
    setState(() {
      _manualClient = exact;
      if (exact != null) {
        _manualFrequent = exact.isFrequent;
        _manualPhoneCtrl.text = exact.phone ?? _manualPhoneCtrl.text;
        _manualAddressCtrl.text = exact.address ?? '';
        _manualInstructionsCtrl.text = exact.deliveryInstructions ?? '';
        _manualAddressOnlyForOrder = false;
      }
    });
  }

  void _selectManualClient(SellerClient client) {
    setState(() {
      _manualClient = client;
      _manualClientCtrl.text = client.name;
      _manualPhoneCtrl.text = client.phone ?? '';
      _manualAddressCtrl.text = client.address ?? '';
      _manualInstructionsCtrl.text = client.deliveryInstructions ?? '';
      _manualFrequent = client.isFrequent;
      _manualAddressOnlyForOrder = false;
    });
    _manualProductFocus.requestFocus();
  }

  void _addManualItem() {
    final item = _buildDraftItem(
      _manualItemNameCtrl.text,
      _manualItemQtyCtrl.text,
      _manualItemPriceCtrl.text,
    );
    if (item == null) {
      _snack('Completa producto, cantidad y precio');
      return;
    }
    setState(() {
      _manualItems.add(item);
      _manualItemNameCtrl.clear();
      _manualItemPriceCtrl.clear();
      _manualItemQtyCtrl.text = '1';
    });
    _manualProductFocus.requestFocus();
  }

  void _cancelManualItem() {
    setState(() {
      _manualItemNameCtrl.clear();
      _manualItemPriceCtrl.clear();
      _manualItemQtyCtrl.text = '1';
    });
    FocusScope.of(context).unfocus();
  }

  void _pickManualProduct(CommonProduct product) {
    setState(() {
      _manualItemNameCtrl.text = product.name;
      _manualItemPriceCtrl.text = _cleanMoney(product.typicalPrice);
      _manualItemQtyCtrl.text = '1';
    });
    _manualProductFocus.requestFocus();
  }

  DraftOrderItem? _buildDraftItem(String name, String qtyRaw, String priceRaw) {
    final productName = name.trim();
    final quantity = int.tryParse(qtyRaw.trim()) ?? 1;
    final price = double.tryParse(priceRaw.trim().replaceAll(',', '')) ?? 0;
    if (productName.isEmpty || quantity < 1 || price <= 0) return null;
    return DraftOrderItem(
      name: productName,
      quantity: quantity,
      unitPrice: price,
    );
  }

  Future<void> _createManualOrder() async {
    if (_creatingManual) return;
    final clientName = _manualClientCtrl.text.trim();
    if (clientName.isEmpty) {
      _snack('Escribe el nombre de la clienta');
      return;
    }
    if (_manualItems.isEmpty) {
      _snack('Agrega al menos un articulo');
      return;
    }

    setState(() => _creatingManual = true);
    try {
      final address = _manualAddressCtrl.text.trim();
      final order = await ref
          .read(sellerOrdersRepositoryProvider)
          .createManual(
            clientName: clientName,
            clientPhone: _manualPhoneCtrl.text.trim(),
            clientAddress: _manualAddressOnlyForOrder ? null : address,
            alternativeAddress: _manualAddressOnlyForOrder ? address : null,
            deliveryInstructions: _manualInstructionsCtrl.text.trim(),
            scheduledDeliveryDate: _manualScheduledDate,
            clientId: _manualClient?.id,
            type: _manualFrequent ? 'Frecuente' : 'Nueva',
            orderType: _manualDelivery,
            items: _manualItems,
          );
      _afterOrderCreated(order);
      _resetManual();
      _snack('Pedido #${order.id} creado', color: const Color(0xFF12A150));
    } catch (e) {
      _snack(e.toString(), color: const Color(0xFFE11D5B));
    } finally {
      if (mounted) setState(() => _creatingManual = false);
    }
  }

  void _resetManual() {
    setState(() {
      _manualClient = null;
      _manualClientCtrl.clear();
      _manualPhoneCtrl.clear();
      _manualAddressCtrl.clear();
      _manualInstructionsCtrl.clear();
      _manualItemNameCtrl.clear();
      _manualItemPriceCtrl.clear();
      _manualItemQtyCtrl.text = '1';
      _manualFrequent = false;
      _manualAddressOnlyForOrder = false;
      _manualDelivery = SellerDeliveryType.delivery;
      _manualScheduledDate = null;
      _manualItems.clear();
    });
  }

  String _quickSearchTerm() {
    final input = _quickInputCtrl.text.trim();
    if (input.isEmpty) return '';
    if (_pinnedProduct != null) {
      return input.split(',').first.trim();
    }
    return input.contains(',')
        ? input.split(',').first.trim()
        : input.split(' ').first;
  }

  void _pickQuickClient(SellerClient client) {
    final input = _quickInputCtrl.text.trim();
    final commaIndex = input.indexOf(',');
    setState(() {
      if (commaIndex >= 0) {
        _quickInputCtrl.text = '${client.name}${input.substring(commaIndex)}';
      } else {
        _quickInputCtrl.text = '${client.name}, ';
      }
      _quickInputCtrl.selection = TextSelection.collapsed(
        offset: _quickInputCtrl.text.length,
      );
    });
    _quickFocus.requestFocus();
  }

  void _pinProduct() {
    final name = _pinNameCtrl.text.trim();
    final price =
        double.tryParse(_pinPriceCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (name.isEmpty || price <= 0) {
      _snack('Escribe producto y precio para fijarlo');
      return;
    }
    setState(() {
      _pinnedProduct = CommonProduct(name: name, count: 0, typicalPrice: price);
      _pinNameCtrl.clear();
      _pinPriceCtrl.clear();
    });
    _quickFocus.requestFocus();
  }

  void _addQuickEntry(List<SellerClient> clients) {
    final input = _quickInputCtrl.text.trim();
    if (input.isEmpty) return;

    QuickCaptureDraft? parsed;
    SellerClient? matched;
    if (_pinnedProduct != null) {
      final commaIndex = input.indexOf(',');
      final clientText = commaIndex >= 0
          ? input.substring(0, commaIndex)
          : input;
      final variant = commaIndex >= 0
          ? input.substring(commaIndex + 1).trim()
          : '';
      matched = _findBestClientMatch(
        clients,
        clientText,
        exactOnly: commaIndex < 0,
      );
      final clientName = matched?.name ?? capitalizeWords(clientText);
      final productName = variant.isEmpty
          ? _pinnedProduct!.name
          : '${_pinnedProduct!.name} ${capitalizeWords(variant)}';
      parsed = QuickCaptureDraft(
        clientName: clientName,
        productName: productName,
        quantity: 1,
        unitPrice: _pinnedProduct!.typicalPrice,
      );
    } else {
      parsed = parseQuickCapture(input);
      if (!input.contains(',')) {
        matched = _findClientPrefix(clients, input);
        if (matched != null) {
          final remaining = input.substring(matched.name.length).trim();
          final productParsed = parseQuickProductCapture(
            clientName: matched.name,
            productText: remaining,
          );
          if (productParsed != null) parsed = productParsed;
        }
      }
      matched ??= parsed == null
          ? null
          : _findBestClientMatch(clients, parsed.clientName);
    }

    if (parsed == null) {
      _snack('Formato rapido: Clienta, articulo, precio');
      return;
    }
    final draft = parsed;

    setState(() {
      _quickQueue.insert(
        0,
        _QuickQueueItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          clientName: matched?.name ?? draft.clientName,
          productName: draft.productName,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          clientId: matched?.id,
          isExistingClient: matched != null,
        ),
      );
      _quickInputCtrl.clear();
    });
    _quickFocus.requestFocus();
  }

  SellerClient? _findClientPrefix(List<SellerClient> clients, String input) {
    final normalized = normalizeCaptureText(input);
    final sorted = [...clients]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final client in sorted) {
      final name = normalizeCaptureText(client.name);
      if (normalized == name || normalized.startsWith('$name ')) return client;
    }
    return null;
  }

  SellerClient? _findBestClientMatch(
    List<SellerClient> clients,
    String input, {
    bool exactOnly = false,
  }) {
    final normalized = normalizeCaptureText(input);
    if (normalized.isEmpty) return null;
    final sorted = [...clients]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final client in sorted) {
      final name = normalizeCaptureText(client.name);
      if (exactOnly) {
        if (normalized == name) return client;
      } else if (normalized == name || normalized.startsWith('$name ')) {
        return client;
      }
    }
    return null;
  }

  List<_QueueGroup> _queueGroups() {
    final map = <String, List<_QuickQueueItem>>{};
    for (final item in _quickQueue) {
      final key = normalizeCaptureText(item.clientName);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map.entries
        .map(
          (entry) => _QueueGroup(
            key: entry.key,
            clientName: entry.value.first.clientName,
            items: entry.value,
          ),
        )
        .toList();
  }

  Future<void> _submitQuickQueue(List<SellerClient> clients) async {
    final groups = _queueGroups();
    if (_submittingQuick || groups.isEmpty) return;

    setState(() {
      _submittingQuick = true;
      _quickProgress = null;
    });
    var successCount = 0;

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      setState(
        () => _quickProgress = '${group.clientName} ${i + 1}/${groups.length}',
      );
      final client = group.clientId == null
          ? _findBestClientMatch(clients, group.clientName, exactOnly: true)
          : clients.where((c) => c.id == group.clientId).firstOrNull;

      try {
        final order = await ref
            .read(sellerOrdersRepositoryProvider)
            .createManual(
              clientName: group.clientName,
              clientId: group.clientId ?? client?.id,
              type: (client?.isFrequent ?? false) ? 'Frecuente' : 'Nueva',
              orderType: _quickDelivery,
              items: group.items
                  .map(
                    (i) => DraftOrderItem(
                      name: i.productName,
                      quantity: i.quantity,
                      unitPrice: i.unitPrice,
                    ),
                  )
                  .toList(),
            );
        successCount++;
        _afterOrderCreated(order);
      } catch (e) {
        _snack(
          'Error con ${group.clientName}: $e',
          color: const Color(0xFFE11D5B),
        );
      }
    }

    setState(() {
      _submittingQuick = false;
      _quickProgress = null;
      if (successCount > 0) _quickQueue.clear();
    });
    if (successCount > 0) {
      _snack('$successCount pedido(s) creados', color: const Color(0xFF12A150));
    }
  }

  void _afterOrderCreated(SellerOrder order) {
    ref.invalidate(sellerOrdersControllerProvider);
    ref.invalidate(sellerDashboardProvider);
    setState(() => _createdOrders.insert(0, order));
  }

  Future<void> _copyCreatedMessages() async {
    final text = _createdOrders.map(buildSellerOrderMessage).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Mensajes copiados', color: const Color(0xFF7C5AC9));
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _manualScheduledDate ?? _nextSunday(),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (picked != null) setState(() => _manualScheduledDate = picked);
  }

  DateTime _nextSunday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime.sunday - today.weekday;
    return today.add(Duration(days: days <= 0 ? days + 7 : days));
  }

  String _cleanMoney(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
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
          _RoundButton(
            icon: Icons.adaptive.arrow_back,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.h2.copyWith(fontSize: 16),
                  children: [
                    const TextSpan(text: 'Captura '),
                    TextSpan(
                      text: 'pedidos',
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

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});
  final _CaptureMode mode;
  final ValueChanged<_CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x123A2233),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Rapido',
            icon: Symbols.bolt,
            selected: mode == _CaptureMode.quick,
            onTap: () => onChanged(_CaptureMode.quick),
          ),
          _ModeButton(
            label: 'Manual',
            icon: Symbols.edit_note,
            selected: mode == _CaptureMode.manual,
            onTap: () => onChanged(_CaptureMode.manual),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected ? AppShadows.small : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.neniDeep : AppColors.ink2,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.neniDeep : AppColors.ink2,
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

class _QuickHero extends StatelessWidget {
  const _QuickHero({
    required this.input,
    required this.focusNode,
    required this.delivery,
    required this.pinnedProduct,
    required this.submitting,
    required this.progress,
    required this.onDeliveryChanged,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClearPin,
  });

  final TextEditingController input;
  final FocusNode focusNode;
  final SellerDeliveryType delivery;
  final CommonProduct? pinnedProduct;
  final bool submitting;
  final String? progress;
  final ValueChanged<SellerDeliveryType> onDeliveryChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearPin;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Symbols.bolt,
      title: 'Modo rapido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinnedProduct != null) ...[
            _PinnedBanner(product: pinnedProduct!, onClear: onClearPin),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: input,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: pinnedProduct == null
                  ? 'Clienta, articulo, precio'
                  : 'Clienta o Clienta, variante',
              prefixIcon: const Icon(
                Symbols.flash_on,
                color: AppColors.neniDeep,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.keyboard_return),
                onPressed: () => onSubmitted(input.text),
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.neniDeep,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DeliveryToggle(value: delivery, onChanged: onDeliveryChanged),
          if (submitting && progress != null) ...[
            const SizedBox(height: 10),
            Text(
              'Guardando $progress',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.neniDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({required this.product, required this.onClear});
  final CommonProduct product;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x33E84E83)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.keep, size: 18, color: AppColors.neniDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${product.name} · ${money(product.typicalPrice)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.neniDeep,
              ),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Symbols.close, size: 18),
            color: AppColors.ink2,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PinProductCard extends StatelessWidget {
  const _PinProductCard({
    required this.name,
    required this.price,
    required this.pinned,
    required this.products,
    required this.onPin,
    required this.onPickProduct,
    required this.onClear,
  });

  final TextEditingController name;
  final TextEditingController price;
  final CommonProduct? pinned;
  final List<CommonProduct> products;
  final VoidCallback onPin;
  final ValueChanged<CommonProduct> onPickProduct;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Symbols.keep,
      title: 'Producto fijo',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniField(controller: name, hint: 'Producto'),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: _MiniField(
                  controller: price,
                  hint: 'Precio',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(icon: Symbols.keep, onTap: onPin),
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProductChips(
              products: products.take(6).toList(),
              onPick: onPickProduct,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickQueuePanel extends StatelessWidget {
  const _QuickQueuePanel({
    required this.groups,
    required this.total,
    required this.submitting,
    required this.onSubmit,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final List<_QueueGroup> groups;
  final double total;
  final bool submitting;
  final VoidCallback? onSubmit;
  final ValueChanged<String> onRemove;
  final void Function(_QuickQueueItem item, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Symbols.receipt_long,
      title: 'Cola (${groups.length})',
      child: Column(
        children: [
          if (groups.isEmpty)
            const _EmptyCaptureState(
              icon: Symbols.playlist_add,
              title: 'Sin pedidos en cola',
              message: 'Captura una linea y presiona Enter.',
            )
          else
            for (final group in groups)
              _QueueGroupCard(
                group: group,
                onRemove: onRemove,
                onQuantityChanged: onQuantityChanged,
              ),
          const SizedBox(height: 12),
          _SubmitBar(
            label: submitting ? 'Guardando...' : 'Crear pedidos',
            total: total,
            disabled: onSubmit == null || submitting,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _QueueGroupCard extends StatelessWidget {
  const _QueueGroupCard({
    required this.group,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final _QueueGroup group;
  final ValueChanged<String> onRemove;
  final void Function(_QuickQueueItem item, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ClientInitial(name: group.clientName),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  group.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                money(group.total),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.neniDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in group.items)
            _CompactItemRow(
              name: item.productName,
              qty: item.quantity,
              unitPrice: item.unitPrice,
              onMinus: () => onQuantityChanged(item, item.quantity - 1),
              onPlus: () => onQuantityChanged(item, item.quantity + 1),
              onRemove: () => onRemove(item.id),
            ),
        ],
      ),
    );
  }
}

class _ManualItemsList extends StatelessWidget {
  const _ManualItemsList({
    required this.items,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final List<DraftOrderItem> items;
  final ValueChanged<DraftOrderItem> onRemove;
  final void Function(DraftOrderItem item, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCaptureState(
        icon: Symbols.shopping_cart,
        title: 'Ticket vacio',
        message: 'Agrega articulos para crear el pedido.',
      );
    }
    return Column(
      children: [
        for (final item in items)
          _CompactItemRow(
            name: item.name,
            qty: item.quantity,
            unitPrice: item.unitPrice,
            onMinus: () => onQuantityChanged(item, item.quantity - 1),
            onPlus: () => onQuantityChanged(item, item.quantity + 1),
            onRemove: () => onRemove(item),
          ),
      ],
    );
  }
}

class _CompactItemRow extends StatelessWidget {
  const _CompactItemRow({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final String name;
  final int qty;
  final double unitPrice;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          _Stepper(qty: qty, onMinus: onMinus, onPlus: onPlus),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${money(unitPrice)} c/u',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(
            money(unitPrice * qty),
            style: AppTextStyles.body.copyWith(
              color: AppColors.neniDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Symbols.close, size: 18),
            color: AppColors.ink3,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ManualAddItemForm extends StatelessWidget {
  const _ManualAddItemForm({
    required this.name,
    required this.price,
    required this.qty,
    required this.focusNode,
    required this.suggestions,
    required this.onPickProduct,
    required this.onAdd,
    required this.onCancel,
  });

  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController qty;
  final FocusNode focusNode;
  final List<CommonProduct> suggestions;
  final ValueChanged<CommonProduct> onPickProduct;
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
                  'Agregar articulo',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neniDeep,
                  ),
                ),
              ),
              _SmallTextAction(label: 'Cancelar', onTap: onCancel),
            ],
          ),
          const SizedBox(height: 9),
          _MiniField(
            controller: name,
            focusNode: focusNode,
            hint: 'Nombre del producto',
            onSubmitted: (_) => onAdd(),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ProductChips(products: suggestions, onPick: onPickProduct),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  controller: price,
                  hint: 'Precio',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 66,
                child: _MiniField(
                  controller: qty,
                  hint: 'Cant.',
                  center: true,
                  keyboard: TextInputType.number,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(icon: Symbols.add, onTap: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualSummary extends StatelessWidget {
  const _ManualSummary({
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.creating,
    required this.canCreate,
    required this.onCreate,
  });

  final double subtotal;
  final double shipping;
  final double total;
  final bool creating;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Symbols.receipt,
      title: 'Resumen',
      child: Column(
        children: [
          _SumLine(label: 'Subtotal', value: money(subtotal)),
          _SumLine(label: 'Envio', value: money(shipping)),
          const SizedBox(height: 12),
          _SubmitBar(
            label: creating ? 'Guardando...' : 'Crear pedido',
            total: total,
            disabled: creating || !canCreate,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.label,
    required this.total,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final double total;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FE84E83)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL', style: AppTextStyles.eyebrow(AppColors.ink3)),
                GradientText(money(total), fontSize: 24),
              ],
            ),
          ),
          _PrimaryAction(label: label, disabled: disabled, onTap: onTap),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.neni, AppColors.neniDeep],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: AppShadows.brandSmall(AppColors.neniDeep),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.button.copyWith(fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientSuggestions extends StatelessWidget {
  const _ClientSuggestions({required this.clients, required this.onPick});
  final List<SellerClient> clients;
  final ValueChanged<SellerClient> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          for (final client in clients)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: _ClientInitial(name: client.name),
              title: Text(
                client.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                client.isFrequent ? 'Frecuente' : 'Nueva',
                style: AppTextStyles.subtitle.copyWith(fontSize: 11),
              ),
              onTap: () => onPick(client),
            ),
        ],
      ),
    );
  }
}

class _ProductChips extends StatelessWidget {
  const _ProductChips({required this.products, required this.onPick});
  final List<CommonProduct> products;
  final ValueChanged<CommonProduct> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final product in products)
            ActionChip(
              label: Text(
                '${product.name} · ${money(product.typicalPrice)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              labelStyle: AppTextStyles.chip.copyWith(
                color: AppColors.neniDeep,
                fontSize: 10.5,
              ),
              backgroundColor: const Color(0xFFFFF5FA),
              side: const BorderSide(color: Color(0x26E84E83)),
              onPressed: () => onPick(product),
            ),
        ],
      ),
    );
  }
}

class _DeliveryToggle extends StatelessWidget {
  const _DeliveryToggle({required this.value, required this.onChanged});

  final SellerDeliveryType value;
  final ValueChanged<SellerDeliveryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0D3A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: 'A domicilio',
            icon: Symbols.local_shipping,
            active: value == SellerDeliveryType.delivery,
            onTap: () => onChanged(SellerDeliveryType.delivery),
          ),
          _ToggleBtn(
            label: 'Recoger',
            icon: Symbols.storefront,
            active: value == SellerDeliveryType.pickup,
            onTap: () => onChanged(SellerDeliveryType.pickup),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active ? AppShadows.small : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.neniDeep : AppColors.ink2,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.neniDeep : AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequentToggle extends StatelessWidget {
  const _FrequentToggle({
    required this.value,
    required this.locked,
    this.onTap,
  });

  final bool value;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFFF0F7) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: value ? const Color(0x66E84E83) : AppColors.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              locked ? Symbols.verified : Symbols.sync_alt,
              size: 17,
              color: value ? AppColors.neniDeep : AppColors.ink2,
            ),
            const SizedBox(width: 5),
            Text(
              value ? 'Frecuente' : 'Nueva',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: value ? AppColors.neniDeep : AppColors.ink2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.onPick,
    required this.onNextSunday,
    this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onNextSunday;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'Fecha programada opcional'
        : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}';
    return Row(
      children: [
        Expanded(
          child: _SmallTextAction(
            label: label,
            icon: Symbols.calendar_month,
            onTap: onPick,
          ),
        ),
        const SizedBox(width: 8),
        _SmallTextAction(
          label: 'Domingo',
          icon: Symbols.event_available,
          onTap: onNextSunday,
        ),
        if (onClear != null) ...[
          const SizedBox(width: 8),
          _IconAction(icon: Symbols.close, onTap: onClear!),
        ],
      ],
    );
  }
}

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Icon(
            value ? Symbols.check_box : Symbols.check_box_outline_blank,
            size: 20,
            color: value ? AppColors.neniDeep : AppColors.ink3,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboard,
    this.textInputAction,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final TextInputAction? textInputAction;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      style: AppTextStyles.body.copyWith(fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, size: 19, color: AppColors.ink3),
        hintText: hint,
        hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.neniDeep, width: 1.3),
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.keyboard,
    this.center = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final TextInputType? keyboard;
  final bool center;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboard,
      textAlign: center ? TextAlign.center : TextAlign.start,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
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
          borderSide: const BorderSide(color: AppColors.neniDeep),
        ),
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

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _SmallTextAction extends StatelessWidget {
  const _SmallTextAction({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.ink2),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientInitial extends StatelessWidget {
  const _ClientInitial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE6F0), Color(0xFFEAE1FF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.body.copyWith(
          color: AppColors.neniDeep,
          fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedOrdersPanel extends StatelessWidget {
  const _CreatedOrdersPanel({required this.orders, required this.onCopyAll});
  final List<SellerOrder> orders;
  final VoidCallback onCopyAll;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Symbols.check_circle,
      title: 'Creados',
      child: Column(
        children: [
          for (final order in orders.take(4))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FFF9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x3327A769)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.id} · ${order.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    money(order.total),
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFF14804A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          _SmallTextAction(
            label: 'Copiar mensajes',
            icon: Symbols.content_copy,
            onTap: onCopyAll,
          ),
        ],
      ),
    );
  }
}

class _EmptyCaptureState extends StatelessWidget {
  const _EmptyCaptureState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x0D3A2233),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.ink3),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CaptureLoading extends StatelessWidget {
  const _CaptureLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            height: i == 0 ? 54 : 132,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
          ),
      ],
    );
  }
}

class _CaptureError extends StatelessWidget {
  const _CaptureError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      children: [
        _EmptyCaptureState(
          icon: Symbols.wifi_off,
          title: 'No pudimos cargar captura',
          message: message,
        ),
        const SizedBox(height: 12),
        _PrimaryAction(label: 'Reintentar', disabled: false, onTap: onRetry),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

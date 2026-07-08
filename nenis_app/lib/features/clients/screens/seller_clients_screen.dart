import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/seller_clients_models.dart';
import '../data/seller_clients_repository.dart';

class SellerClientsScreen extends ConsumerStatefulWidget {
  const SellerClientsScreen({super.key});

  @override
  ConsumerState<SellerClientsScreen> createState() =>
      _SellerClientsScreenState();
}

class _SellerClientsScreenState extends ConsumerState<SellerClientsScreen> {
  final _searchCtrl = TextEditingController();
  SellerClientSegment _segment = SellerClientSegment.all;
  SellerClientSort _sort = SellerClientSort.spent;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    ref.invalidate(sellerClientsProvider);
    await ref.read(sellerClientsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.neniDeep,
            onRefresh: _reload,
            child: async.when(
              loading: _buildLoading,
              error: (error, _) => _buildError(error),
              data: _buildContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
      children: [
        _Header(
          total: 0,
          sortLabel: _sort.label,
          locating: false,
          onRefresh: () => ref.invalidate(sellerClientsProvider),
          onSort: _showSortSheet,
          onDuplicates: _showDuplicateSuggestionsSheet,
          onLocate: null,
        ),
        const SizedBox(height: 16),
        const _Skeleton(height: 112),
        const SizedBox(height: 12),
        const _Skeleton(height: 54),
        const SizedBox(height: 18),
        for (var i = 0; i < 5; i++) ...[
          const _Skeleton(height: 148),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildError(Object error) {
    final message = error is SellerClientsException
        ? error.message
        : 'No pudimos cargar las clientas.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 90, 28, 120),
      children: [
        _EmptyState(
          icon: Symbols.wifi_off,
          title: 'Sin conexión con clientas',
          message: message,
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(sellerClientsProvider),
        ),
      ],
    );
  }

  Widget _buildContent(List<SellerClientProfile> clients) {
    final visible = _visibleClients(clients);
    final needsLocation = clients
        .where((client) => client.needsLocation)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
      children: [
        _Header(
          total: clients.length,
          sortLabel: _sort.label,
          locating: _locating,
          onRefresh: () => ref.invalidate(sellerClientsProvider),
          onSort: _showSortSheet,
          onDuplicates: _showDuplicateSuggestionsSheet,
          onLocate: needsLocation == 0 ? null : () => _bulkGeocode(clients),
        ),
        const SizedBox(height: 14),
        _StatsGrid(clients: clients),
        const SizedBox(height: 14),
        _SearchBox(controller: _searchCtrl, onClear: _searchCtrl.clear),
        const SizedBox(height: 12),
        _SegmentChips(
          selected: _segment,
          onChanged: (value) => setState(() => _segment = value),
        ),
        const SizedBox(height: 14),
        _ResultsLine(
          visibleCount: visible.length,
          totalCount: clients.length,
          sortLabel: _sort.label,
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          _EmptyState(
            icon: Symbols.manage_search,
            title: 'No encontré clientas',
            message: 'Prueba con otro nombre, teléfono, dirección o filtro.',
            actionLabel: 'Limpiar filtros',
            onAction: _clearFilters,
          )
        else
          for (final client in visible)
            Padding(
              key: ValueKey(client.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClientCard(
                client: client,
                onTap: () => _showClientSheet(client.id),
                onCall: client.hasPhone ? () => _call(client.phone) : null,
                onWhatsApp: client.hasPhone
                    ? () => _openWhatsApp(client.phone)
                    : null,
                onMap: client.hasAddress || client.hasCoordinates
                    ? () => _openMap(client)
                    : null,
              ),
            ),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _segment = SellerClientSegment.all;
    });
  }

  List<SellerClientProfile> _visibleClients(List<SellerClientProfile> clients) {
    final query = _normalize(_searchCtrl.text);
    final filtered = clients.where((client) {
      final matchesQuery =
          query.isEmpty || _normalize(client.searchableText).contains(query);
      if (!matchesQuery) return false;

      return switch (_segment) {
        SellerClientSegment.all => true,
        SellerClientSegment.newClients => !client.isFrequent,
        SellerClientSegment.frequent => client.isFrequent,
        SellerClientSegment.vip => client.isVip,
        SellerClientSegment.needsAddress => client.needsAddress,
        SellerClientSegment.needsLocation => client.needsLocation,
      };
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        SellerClientSort.spent => b.totalSpent.compareTo(a.totalSpent),
        SellerClientSort.orders => b.ordersCount.compareTo(a.ordersCount),
        SellerClientSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        SellerClientSort.location => _locationScore(
          b,
        ).compareTo(_locationScore(a)),
      };
    });

    return filtered;
  }

  int _locationScore(SellerClientProfile client) {
    if (client.needsAddress) return 2;
    if (client.needsLocation) return 1;
    return 0;
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<SellerClientSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SortSheet(selected: _sort),
    );
    if (selected == null || selected == _sort) return;
    setState(() => _sort = selected);
  }

  Future<void> _showDuplicateSuggestionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _DuplicateSuggestionsSheet(onMerge: _mergeDuplicateSuggestion),
    );
  }

  Future<void> _mergeDuplicateSuggestion(
    SellerDuplicateSuggestion suggestion,
    int targetId,
  ) async {
    final sourceId = suggestion.sourceIdForTarget(targetId);
    final sourceName = suggestion.nameFor(sourceId);
    final targetName = suggestion.nameFor(targetId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fusionar clientas'),
        content: Text(
          'Se moveran pedidos, puntos y alias de "$sourceName" a "$targetName". '
          '"$sourceName" se eliminara del directorio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fusionar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(sellerClientsRepositoryProvider)
          .mergeClients(sourceId: sourceId, targetId: targetId);
      ref.invalidate(sellerClientsProvider);
      ref.invalidate(sellerClientDuplicateSuggestionsProvider);
      ref.invalidate(sellerClientDetailProvider(sourceId));
      ref.invalidate(sellerClientDetailProvider(targetId));
      ref.invalidate(sellerClientAliasesProvider(targetId));
      _snack('Clientas fusionadas.');
    } catch (error) {
      _snack(error.toString(), danger: true);
    }
  }

  Future<void> _showClientSheet(int clientId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientDetailSheet(
        clientId: clientId,
        onEdit: _editClient,
        onAddAlias: _addAlias,
        onCall: _call,
        onWhatsApp: _openWhatsApp,
        onMap: _openMap,
        onCopyAddress: _copyAddress,
      ),
    );
  }

  Future<void> _editClient(SellerClientProfile client) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientEditSheet(
        client: client,
        onSave: (request) => _saveClient(client.id, request),
        onDelete: () => _deleteClient(client),
      ),
    );

    if (deleted == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveClient(
    int clientId,
    UpdateSellerClientRequest request,
  ) async {
    await ref
        .read(sellerClientsRepositoryProvider)
        .updateClient(clientId, request);
    ref.invalidate(sellerClientsProvider);
    ref.invalidate(sellerClientDetailProvider(clientId));
    _snack('Clienta guardada.');
  }

  Future<bool> _deleteClient(SellerClientProfile client) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar clienta'),
        content: Text(
          client.ordersCount > 0
              ? 'Esta clienta tiene ${client.ordersCount} pedido(s). El API puede rechazar la eliminación para proteger el historial.'
              : 'Se eliminará ${client.name}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    await ref.read(sellerClientsRepositoryProvider).deleteClient(client.id);
    ref.invalidate(sellerClientsProvider);
    ref.invalidate(sellerClientDetailProvider(client.id));
    _snack('Clienta eliminada.');
    return true;
  }

  Future<void> _addAlias(int clientId) async {
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => const _AliasDialog(),
    );
    final value = alias?.trim();
    if (value == null || value.isEmpty) return;

    try {
      await ref.read(sellerClientsRepositoryProvider).addAlias(clientId, value);
      ref.invalidate(sellerClientAliasesProvider(clientId));
      ref.invalidate(sellerClientsProvider);
      _snack('Alias agregado.');
    } catch (error) {
      _snack(error.toString(), danger: true);
    }
  }

  Future<void> _bulkGeocode(List<SellerClientProfile> clients) async {
    if (_locating) return;
    final targets = clients
        .where((client) => client.needsLocation)
        .map((client) => client.id)
        .toList();
    if (targets.isEmpty) {
      _snack('No hay direcciones pendientes de ubicar.');
      return;
    }

    setState(() => _locating = true);
    try {
      final result = await ref
          .read(sellerClientsRepositoryProvider)
          .bulkGeocode(targets);
      final ok = result.where((item) => item.success).length;
      final failed = result.length - ok;
      ref.invalidate(sellerClientsProvider);
      _snack(
        failed == 0
            ? 'Ubicamos $ok dirección(es).'
            : 'Ubicadas $ok, pendientes $failed.',
      );
    } catch (error) {
      _snack(error.toString(), danger: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _call(String? phone) async {
    final digits = _digits(phone);
    if (digits.isEmpty) {
      _snack('Esta clienta no tiene teléfono.', danger: true);
      return;
    }
    await _launch(Uri(scheme: 'tel', path: digits));
  }

  Future<void> _openWhatsApp(String? phone) async {
    final digits = _digits(phone);
    if (digits.isEmpty) {
      _snack('Esta clienta no tiene teléfono.', danger: true);
      return;
    }
    final normalized = digits.length == 10 ? '52$digits' : digits;
    await _launch(Uri.parse('https://wa.me/$normalized'));
  }

  Future<void> _openMap(SellerClientProfile client) async {
    final Uri uri;
    if (client.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${client.latitude},${client.longitude}',
      );
    } else if (client.hasAddress) {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': client.address!,
      });
    } else {
      _snack('Esta clienta no tiene dirección.', danger: true);
      return;
    }
    await _launch(uri);
  }

  Future<void> _copyAddress(SellerClientProfile client) async {
    final address = client.address?.trim();
    if (address == null || address.isEmpty) {
      _snack('Esta clienta no tiene dirección.', danger: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    _snack('Dirección copiada.');
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('No pudimos abrir esa acción.', danger: true);
  }

  String _digits(String? phone) => (phone ?? '').replaceAll(RegExp(r'\D'), '');

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: danger ? AppColors.liveRed : AppColors.ink,
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.sortLabel,
    required this.locating,
    required this.onRefresh,
    required this.onSort,
    required this.onDuplicates,
    this.onLocate,
  });

  final int total;
  final String sortLabel;
  final bool locating;
  final VoidCallback onRefresh;
  final VoidCallback onSort;
  final VoidCallback onDuplicates;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTextStyles.h1.copyWith(fontSize: 27),
                  children: [
                    const TextSpan(text: 'Clientas '),
                    TextSpan(
                      text: 'VIP',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 27,
                        color: AppColors.neniDeep,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                total == 0
                    ? 'Directorio conectado a sellgeneral-api.'
                    : '$total perfiles, orden: $sortLabel.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _IconTile(
          tooltip: locating ? 'Ubicando...' : 'Ubicar direcciones',
          icon: locating ? Symbols.progress_activity : Symbols.add_location_alt,
          onTap: locating ? null : onLocate,
        ),
        const SizedBox(width: 8),
        _IconTile(
          tooltip: 'Fusionar duplicadas',
          icon: Icons.merge_type_rounded,
          onTap: onDuplicates,
        ),
        const SizedBox(width: 8),
        _IconTile(tooltip: 'Ordenar', icon: Symbols.tune, onTap: onSort),
        const SizedBox(width: 8),
        _IconTile(tooltip: 'Actualizar', icon: Symbols.sync, onTap: onRefresh),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.clients});

  final List<SellerClientProfile> clients;

  @override
  Widget build(BuildContext context) {
    final frequent = clients.where((client) => client.isFrequent).length;
    final vip = clients.where((client) => client.isVip).length;
    final needsAddress = clients.where((client) => client.needsAddress).length;
    final needsLocation = clients
        .where((client) => client.needsLocation)
        .length;
    final totalSpent = clients.fold<double>(
      0,
      (sum, client) => sum + client.totalSpent,
    );

    final items = [
      _KpiData(
        'Venta total',
        clientMoney(totalSpent),
        Symbols.payments,
        AppColors.statusDeliveredFg,
      ),
      _KpiData(
        'Frecuentes',
        frequent.toString(),
        Symbols.verified,
        AppColors.lavender,
      ),
      _KpiData('Consentidas', vip.toString(), Symbols.crown, AppColors.gold),
      _KpiData(
        'Por completar',
        (needsAddress + needsLocation).toString(),
        Symbols.location_off,
        AppColors.statusPendingFg,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: columns == 4 ? 1.65 : 2.35,
          ),
          itemBuilder: (context, index) => _KpiTile(data: items[index]),
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, size: 19, color: data.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink3,
                  ),
                ),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body.copyWith(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Buscar nombre, teléfono, dirección o alias',
        hintStyle: AppTextStyles.fieldPlaceholder.copyWith(fontSize: 13.5),
        prefixIcon: const Icon(Symbols.search, size: 21, color: AppColors.ink3),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Symbols.close, size: 19),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.fieldRadius,
          borderSide: const BorderSide(color: AppColors.neniDeep, width: 1.2),
        ),
      ),
    );
  }
}

class _SegmentChips extends StatelessWidget {
  const _SegmentChips({required this.selected, required this.onChanged});

  final SellerClientSegment selected;
  final ValueChanged<SellerClientSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final segment in SellerClientSegment.values) ...[
            _FilterChip(
              label: segment.label,
              selected: selected == segment,
              onTap: () => onChanged(segment),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surface,
            borderRadius: AppRadii.pillRadius,
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
            ),
            boxShadow: selected ? AppShadows.small : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.surface : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsLine extends StatelessWidget {
  const _ResultsLine({
    required this.visibleCount,
    required this.totalCount,
    required this.sortLabel,
  });

  final int visibleCount;
  final int totalCount;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Mostrando $visibleCount de $totalCount',
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink3,
            ),
          ),
        ),
        _TinyChip(label: sortLabel, color: AppColors.lavender),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onTap,
    this.onCall,
    this.onWhatsApp,
    this.onMap,
  });

  final SellerClientProfile client;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final address = client.address?.trim();
    final phone = client.phone?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ClientAvatar(client: client, large: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name.isEmpty ? 'Sin nombre' : client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h2.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _TinyChip(
                              label: client.tag.label,
                              color: _tagColor(client.tag),
                            ),
                            _TinyChip(
                              label: client.displayType,
                              color: client.isFrequent
                                  ? AppColors.lavender
                                  : AppColors.neniDeep,
                            ),
                            _TinyChip(
                              label: client.hasCoordinates
                                  ? 'Con mapa'
                                  : client.hasAddress
                                  ? 'Por ubicar'
                                  : 'Sin dirección',
                              color: client.hasCoordinates
                                  ? AppColors.statusDeliveredFg
                                  : AppColors.statusPendingFg,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        clientMoney(client.totalSpent),
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.neniDeep,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${client.ordersCount} ped.',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _InfoLine(
                icon: Symbols.call,
                text: phone?.isNotEmpty == true ? phone! : 'Sin teléfono',
                muted: phone?.isNotEmpty != true,
              ),
              const SizedBox(height: 7),
              _InfoLine(
                icon: Symbols.location_on,
                text: address?.isNotEmpty == true
                    ? address!
                    : 'Sin dirección guardada',
                muted: address?.isNotEmpty != true,
                maxLines: 2,
              ),
              if ((client.deliveryInstructions ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                _InfoLine(
                  icon: Symbols.notes,
                  text: client.deliveryInstructions!.trim(),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _SmallAction(
                      label: 'Llamar',
                      icon: Symbols.call,
                      onTap: onCall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallAction(
                      label: 'WhatsApp',
                      icon: Symbols.chat,
                      onTap: onWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SmallAction(
                      label: 'Mapa',
                      icon: Symbols.map,
                      onTap: onMap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuplicateSuggestionsSheet extends ConsumerWidget {
  const _DuplicateSuggestionsSheet({required this.onMerge});

  final Future<void> Function(
    SellerDuplicateSuggestion suggestion,
    int targetId,
  )
  onMerge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) {
        final async = ref.watch(sellerClientDuplicateSuggestionsProvider);
        return _SheetFrame(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (error, _) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                const _SheetHandle(),
                _EmptyState(
                  icon: Icons.merge_type_rounded,
                  title: 'No pudimos revisar duplicadas',
                  message: error.toString(),
                  actionLabel: 'Reintentar',
                  onAction: () =>
                      ref.invalidate(sellerClientDuplicateSuggestionsProvider),
                ),
              ],
            ),
            data: (suggestions) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                const _SheetHandle(),
                Text(
                  'Duplicadas sugeridas',
                  style: AppTextStyles.h1.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige que perfil conservar. El otro se fusiona y se elimina.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                if (suggestions.isEmpty)
                  const _EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Sin duplicadas por revisar',
                    message:
                        'No encontramos pares con telefono igual o nombres parecidos.',
                  )
                else
                  for (final suggestion in suggestions) ...[
                    _DuplicateSuggestionCard(
                      suggestion: suggestion,
                      onMerge: (targetId) => onMerge(suggestion, targetId),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DuplicateSuggestionCard extends StatelessWidget {
  const _DuplicateSuggestionCard({
    required this.suggestion,
    required this.onMerge,
  });

  final SellerDuplicateSuggestion suggestion;
  final ValueChanged<int> onMerge;

  @override
  Widget build(BuildContext context) {
    final recommendedTargetId = suggestion.recommendedTargetId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAF2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.merge_type_rounded,
                  color: AppColors.neniDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${suggestion.leftName} + ${suggestion.rightName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _TinyChip(
                label: suggestion.reasonLabel,
                color: AppColors.neniDeep,
              ),
              _TinyChip(
                label: suggestion.confidenceLabel,
                color: AppColors.statusRouteFg,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DuplicateClientLine(
            clientId: suggestion.leftClientId,
            name: suggestion.leftName,
            ordersCount: suggestion.leftOrdersCount,
            recommended: suggestion.leftClientId == recommendedTargetId,
          ),
          const SizedBox(height: 8),
          _DuplicateClientLine(
            clientId: suggestion.rightClientId,
            name: suggestion.rightName,
            ordersCount: suggestion.rightOrdersCount,
            recommended: suggestion.rightClientId == recommendedTargetId,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _SmallAction(
                  label: 'Mantener ${_shortClientName(suggestion.leftName)}',
                  icon: Icons.account_circle_outlined,
                  onTap: () => onMerge(suggestion.leftClientId),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallAction(
                  label: 'Mantener ${_shortClientName(suggestion.rightName)}',
                  icon: Icons.account_circle_outlined,
                  onTap: () => onMerge(suggestion.rightClientId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateClientLine extends StatelessWidget {
  const _DuplicateClientLine({
    required this.clientId,
    required this.name,
    required this.ordersCount,
    required this.recommended,
  });

  final int clientId;
  final String name;
  final int ordersCount;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: recommended ? const Color(0xFFFFF5FA) : AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: recommended
              ? AppColors.neniDeep.withValues(alpha: 0.22)
              : AppColors.lineSoft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.trim().isEmpty ? 'Sin nombre' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$ordersCount ped.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 11),
          ),
          if (recommended) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, size: 15, color: AppColors.neniDeep),
          ],
        ],
      ),
    );
  }
}

class _ClientDetailSheet extends ConsumerWidget {
  const _ClientDetailSheet({
    required this.clientId,
    required this.onEdit,
    required this.onAddAlias,
    required this.onCall,
    required this.onWhatsApp,
    required this.onMap,
    required this.onCopyAddress,
  });

  final int clientId;
  final ValueChanged<SellerClientProfile> onEdit;
  final ValueChanged<int> onAddAlias;
  final ValueChanged<String?> onCall;
  final ValueChanged<String?> onWhatsApp;
  final ValueChanged<SellerClientProfile> onMap;
  final ValueChanged<SellerClientProfile> onCopyAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        final async = ref.watch(sellerClientDetailProvider(clientId));
        return _SheetFrame(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neni),
            ),
            error: (error, _) => _SheetError(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(sellerClientDetailProvider(clientId)),
            ),
            data: (client) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                const _SheetHandle(),
                _DetailHeader(client: client, onEdit: () => onEdit(client)),
                const SizedBox(height: 14),
                _ActionGrid(
                  client: client,
                  onCall: () => onCall(client.phone),
                  onWhatsApp: () => onWhatsApp(client.phone),
                  onMap: () => onMap(client),
                  onCopyAddress: () => onCopyAddress(client),
                  onNewOrder: () {
                    Navigator.of(context).pop();
                    context.push('/orders/new');
                  },
                ),
                const SizedBox(height: 14),
                _ContactCard(client: client),
                const SizedBox(height: 14),
                _LoyaltyCard(clientId: client.id),
                const SizedBox(height: 14),
                _AliasesCard(
                  clientId: client.id,
                  onAddAlias: () => onAddAlias(client.id),
                ),
                const SizedBox(height: 14),
                _ClientInsightCard(clientId: client.id),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.ink3.withValues(alpha: 0.55),
          borderRadius: AppRadii.pillRadius,
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.client, required this.onEdit});

  final SellerClientProfile client;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0F6), Color(0xFFF2EAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.neni.withValues(alpha: 0.16)),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientAvatar(client: client, hero: true),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(fontSize: 21),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _TinyChip(
                      label: client.tag.label,
                      color: _tagColor(client.tag),
                    ),
                    _TinyChip(
                      label: client.displayType,
                      color: client.isFrequent
                          ? AppColors.lavender
                          : AppColors.neniDeep,
                    ),
                    _TinyChip(
                      label: '${client.ordersCount} pedidos',
                      color: AppColors.statusRouteFg,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _IconTile(tooltip: 'Editar', icon: Symbols.edit, onTap: onEdit),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.client,
    required this.onCall,
    required this.onWhatsApp,
    required this.onMap,
    required this.onCopyAddress,
    required this.onNewOrder,
  });

  final SellerClientProfile client;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onMap;
  final VoidCallback onCopyAddress;
  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.35,
      children: [
        _ActionTile(
          label: 'Pedido',
          icon: Symbols.add_shopping_cart,
          color: AppColors.neniDeep,
          onTap: onNewOrder,
        ),
        _ActionTile(
          label: 'Llamar',
          icon: Symbols.call,
          color: AppColors.statusRouteFg,
          onTap: client.hasPhone ? onCall : null,
        ),
        _ActionTile(
          label: 'WhatsApp',
          icon: Symbols.chat,
          color: AppColors.statusDeliveredFg,
          onTap: client.hasPhone ? onWhatsApp : null,
        ),
        _ActionTile(
          label: 'Mapa',
          icon: Symbols.map,
          color: AppColors.lavender,
          onTap: client.hasAddress || client.hasCoordinates ? onMap : null,
        ),
        _ActionTile(
          label: 'Copiar dir.',
          icon: Symbols.content_copy,
          color: AppColors.gold,
          onTap: client.hasAddress ? onCopyAddress : null,
        ),
        _ActionTile(
          label: 'Perfil',
          icon: Symbols.badge,
          color: AppColors.ink2,
          onTap: null,
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.client});

  final SellerClientProfile client;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Datos de entrega',
      icon: Symbols.local_shipping,
      child: Column(
        children: [
          _DetailRow(
            icon: Symbols.call,
            label: 'Teléfono',
            value: client.phone?.trim().isNotEmpty == true
                ? client.phone!
                : 'Sin teléfono',
            muted: client.phone?.trim().isNotEmpty != true,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Symbols.location_on,
            label: 'Dirección',
            value: client.address?.trim().isNotEmpty == true
                ? client.address!
                : 'Sin dirección guardada',
            muted: client.address?.trim().isNotEmpty != true,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Symbols.notes,
            label: 'Indicaciones',
            value: client.deliveryInstructions?.trim().isNotEmpty == true
                ? client.deliveryInstructions!
                : 'Sin indicaciones',
            muted: client.deliveryInstructions?.trim().isNotEmpty != true,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: client.hasCoordinates
                ? Symbols.my_location
                : Symbols.location_off,
            label: 'Ubicación exacta',
            value: client.hasCoordinates
                ? '${client.latitude!.toStringAsFixed(5)}, ${client.longitude!.toStringAsFixed(5)}'
                : client.hasAddress
                ? 'Dirección pendiente de geocodificar'
                : 'Sin datos para ubicar',
            muted: !client.hasCoordinates,
          ),
        ],
      ),
    );
  }
}

class _LoyaltyCard extends ConsumerWidget {
  const _LoyaltyCard({required this.clientId});

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sellerClientLoyaltyProvider(clientId));
    final history = ref.watch(sellerClientLoyaltyHistoryProvider(clientId));

    return _SectionCard(
      title: 'RegiPuntos',
      icon: Symbols.stars,
      child: summary.when(
        loading: () => const _MiniLoading(label: 'Cargando puntos...'),
        error: (error, _) => _InlineError(message: error.toString()),
        data: (points) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricBox(
                    label: 'Saldo',
                    value: '${points.currentPoints} pts',
                    color: AppColors.neniDeep,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _MetricBox(
                    label: 'Históricos',
                    value: '${points.lifetimePoints} pts',
                    color: AppColors.lavender,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadii.pillRadius,
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: points.tierProgress.clamp(0, 1).toDouble(),
                      backgroundColor: AppColors.lineSoft,
                      color: AppColors.neniDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                _TinyChip(label: points.tier, color: AppColors.gold),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              points.nextTierLabel,
              style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            history.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) => rows.isEmpty
                  ? Text(
                      'Sin movimientos de puntos todavía.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    )
                  : Column(
                      children: rows.take(3).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: _PointRow(item: item),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AliasesCard extends ConsumerWidget {
  const _AliasesCard({required this.clientId, required this.onAddAlias});

  final int clientId;
  final VoidCallback onAddAlias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerClientAliasesProvider(clientId));
    return _SectionCard(
      title: 'Alias e identidad',
      icon: Symbols.fingerprint,
      trailing: TextButton.icon(
        onPressed: onAddAlias,
        icon: const Icon(Symbols.add, size: 17),
        label: const Text('Alias'),
      ),
      child: async.when(
        loading: () => const _MiniLoading(label: 'Cargando alias...'),
        error: (error, _) => _InlineError(message: error.toString()),
        data: (aliases) => aliases.isEmpty
            ? Text(
                'Agrega apodos o nombres de Facebook para que el sistema reconozca a la misma clienta al capturar pedidos.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: aliases
                    .map(
                      (alias) => _AliasPill(
                        alias: alias,
                        onDelete: alias.id <= 0
                            ? null
                            : () async {
                                await ref
                                    .read(sellerClientsRepositoryProvider)
                                    .deleteAlias(alias.id);
                                ref.invalidate(
                                  sellerClientAliasesProvider(clientId),
                                );
                              },
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class _ClientInsightCard extends ConsumerStatefulWidget {
  const _ClientInsightCard({required this.clientId});

  final int clientId;

  @override
  ConsumerState<_ClientInsightCard> createState() => _ClientInsightCardState();
}

class _ClientInsightCardState extends ConsumerState<_ClientInsightCard> {
  bool _loading = false;
  String? _text;
  String? _error;

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(sellerClientsRepositoryProvider)
          .getClientInsight(widget.clientId);
      setState(() => _text = result.text);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Análisis C.A.M.I.',
      icon: Symbols.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_text == null && _error == null)
            Text(
              'Genera una lectura rápida de hábitos, riesgo de cobro y oportunidad de venta con datos reales de la clienta.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
            ),
          if (_text != null)
            Text(
              _text!,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12.5,
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 12),
          _SmallAction(
            label: _loading
                ? 'Analizando...'
                : _text == null
                ? 'Ver análisis'
                : 'Actualizar análisis',
            icon: Symbols.auto_awesome,
            onTap: _loading ? null : _load,
          ),
        ],
      ),
    );
  }
}

class _ClientEditSheet extends StatefulWidget {
  const _ClientEditSheet({
    required this.client,
    required this.onSave,
    required this.onDelete,
  });

  final SellerClientProfile client;
  final Future<void> Function(UpdateSellerClientRequest request) onSave;
  final Future<bool> Function() onDelete;

  @override
  State<_ClientEditSheet> createState() => _ClientEditSheetState();
}

class _ClientEditSheetState extends State<_ClientEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _facebookCtrl;
  late SellerClientTag _tag;
  late String _type;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameCtrl = TextEditingController(text: client.name);
    _phoneCtrl = TextEditingController(text: client.phone ?? '');
    _addressCtrl = TextEditingController(text: client.address ?? '');
    _instructionsCtrl = TextEditingController(
      text: client.deliveryInstructions ?? '',
    );
    _facebookCtrl = TextEditingController(
      text: client.facebookProfileUrl ?? '',
    );
    _tag = client.tag;
    _type = client.displayType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _instructionsCtrl.dispose();
    _facebookCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        UpdateSellerClientRequest(
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          address: _addressCtrl.text,
          tag: _tag,
          type: _type,
          deliveryInstructions: _instructionsCtrl.text,
          facebookProfileUrl: _facebookCtrl.text.trim().isEmpty
              ? null
              : _facebookCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      final deleted = await widget.onDelete();
      if (deleted && mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                Text(
                  'Editar clienta',
                  style: AppTextStyles.h1.copyWith(fontSize: 23),
                ),
                const SizedBox(height: 14),
                _EditField(
                  label: 'Nombre',
                  controller: _nameCtrl,
                  icon: Symbols.badge,
                  validator: (value) =>
                      value.trim().isEmpty ? 'Escribe el nombre.' : null,
                ),
                const SizedBox(height: 12),
                _EditField(
                  label: 'Teléfono',
                  controller: _phoneCtrl,
                  icon: Symbols.call,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerBox(
                        label: 'Etiqueta',
                        child: DropdownButtonFormField<SellerClientTag>(
                          initialValue: _tag,
                          isExpanded: true,
                          decoration: _fieldDecoration(),
                          items: SellerClientTag.values
                              .map(
                                (tag) => DropdownMenuItem(
                                  value: tag,
                                  child: Text(tag.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _tag = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerBox(
                        label: 'Tipo',
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          isExpanded: true,
                          decoration: _fieldDecoration(),
                          items: const [
                            DropdownMenuItem(
                              value: 'Nueva',
                              child: Text('Nueva'),
                            ),
                            DropdownMenuItem(
                              value: 'Frecuente',
                              child: Text('Frecuente'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _type = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EditField(
                  label: 'Dirección',
                  controller: _addressCtrl,
                  icon: Symbols.location_on,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _EditField(
                  label: 'Indicaciones de entrega',
                  controller: _instructionsCtrl,
                  icon: Symbols.notes,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _EditField(
                  label: 'Facebook o Messenger',
                  controller: _facebookCtrl,
                  icon: Symbols.alternate_email,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 18),
                PillButton(
                  label: _saving ? 'Guardando...' : 'Guardar cambios',
                  icon: Symbols.save,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Cancelar',
                        variant: PillButtonVariant.ghost,
                        icon: Symbols.close,
                        onPressed: _saving || _deleting
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DangerButton(
                        label: _deleting ? 'Eliminando...' : 'Eliminar',
                        onTap: _saving || _deleting ? null : _delete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AliasDialog extends StatefulWidget {
  const _AliasDialog();

  @override
  State<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends State<_AliasDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar alias'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Apodo, nombre de Facebook o variación',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.selected});

  final SellerClientSort selected;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Text('Ordenar clientas', style: AppTextStyles.h1),
            const SizedBox(height: 12),
            for (final option in SellerClientSort.values)
              _SortOption(
                label: option.label,
                selected: option == selected,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.softRadius,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF1F7) : AppColors.surface,
              borderRadius: AppRadii.softRadius,
              border: Border.all(
                color: selected
                    ? AppColors.neniDeep.withValues(alpha: 0.28)
                    : AppColors.line,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Symbols.radio_button_checked : Symbols.circle,
                  size: 20,
                  color: selected ? AppColors.neniDeep : AppColors.ink3,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.neniDeep : AppColors.ink,
                    ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.neniDeep),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.neniDeep,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: muted ? AppColors.lineSoft : const Color(0xFFFFEAF2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: muted ? AppColors.ink3 : AppColors.neniDeep,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 10.5,
                  color: AppColors.ink3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12.5,
                  color: muted ? AppColors.ink3 : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.muted = false,
    this.maxLines = 1,
  });

  final IconData icon;
  final String text;
  final bool muted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted ? AppColors.ink3 : AppColors.ink2),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 11.5,
              color: muted ? AppColors.ink3 : AppColors.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({
    required this.client,
    this.large = false,
    this.hero = false,
  });

  final SellerClientProfile client;
  final bool large;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final size = hero
        ? 68.0
        : large
        ? 48.0
        : 40.0;
    final color = _tagColor(client.tag);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.75), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(hero ? 22 : 16),
        boxShadow: AppShadows.brandSmall(color),
      ),
      alignment: Alignment.center,
      child: Text(
        client.initial,
        style: AppTextStyles.h2.copyWith(
          color: AppColors.surface,
          fontSize: hero ? 25 : 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.chip.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: AppColors.neniDeep),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: AppColors.neniDeep,
                      fontSize: 12,
                    ),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.softRadius,
          child: Ink(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.softRadius,
              border: Border.all(color: AppColors.line),
              boxShadow: AppShadows.small,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow(color).copyWith(fontSize: 8),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.item});

  final SellerClientLoyaltyTransaction item;

  @override
  Widget build(BuildContext context) {
    final positive = item.points > 0;
    final date = DateFormat("d MMM", 'es_MX').format(item.date);
    return Row(
      children: [
        _TinyChip(
          label: positive ? '+${item.points}' : item.points.toString(),
          color: positive ? AppColors.statusDeliveredFg : AppColors.liveRed,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
          ),
        ),
        Text(date, style: AppTextStyles.subtitle.copyWith(fontSize: 10.5)),
      ],
    );
  }
}

class _AliasPill extends StatelessWidget {
  const _AliasPill({required this.alias, this.onDelete});

  final SellerClientAlias alias;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FA),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            alias.alias,
            style: AppTextStyles.chip.copyWith(
              color: AppColors.neniDeep,
              fontSize: 11,
            ),
          ),
          if (alias.timesSeen > 1) ...[
            const SizedBox(width: 5),
            Text(
              'x${alias.timesSeen}',
              style: AppTextStyles.chip.copyWith(
                color: AppColors.ink3,
                fontSize: 10,
              ),
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 3),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Symbols.close, size: 15, color: AppColors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String value)? validator;

  @override
  Widget build(BuildContext context) {
    return _PickerBox(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        decoration: _fieldDecoration(prefixIcon: icon),
        validator: (value) => validator?.call(value ?? ''),
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12,
            color: AppColors.ink2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDecoration({IconData? prefixIcon}) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: AppColors.ink3, size: 19),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.neniDeep, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.liveRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.tooltip, required this.icon, this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.iconBtnRadius,
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.iconBtnRadius,
                border: Border.all(color: AppColors.line),
                boxShadow: AppShadows.small,
              ),
              child: Icon(icon, color: AppColors.ink, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillRadius,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F4),
              borderRadius: AppRadii.pillRadius,
              border: Border.all(
                color: AppColors.liveRed.withValues(alpha: 0.18),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: AppColors.liveRed,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniLoading extends StatelessWidget {
  const _MiniLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.neni,
          ),
        ),
        const SizedBox(width: 9),
        Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.subtitle.copyWith(
        fontSize: 12,
        color: AppColors.liveRed,
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _EmptyState(
        icon: Symbols.error,
        title: 'No pudimos abrir la clienta',
        message: message,
        actionLabel: 'Reintentar',
        onAction: onRetry,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.neniDeep),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            _SmallAction(
              label: actionLabel!,
              icon: Symbols.refresh,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
      ),
    );
  }
}

Color _tagColor(SellerClientTag tag) {
  return switch (tag) {
    SellerClientTag.none => AppColors.neniDeep,
    SellerClientTag.risingStar => AppColors.statusRouteFg,
    SellerClientTag.vip => AppColors.gold,
    SellerClientTag.blacklist => AppColors.liveRed,
  };
}

String _shortClientName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'perfil';
  return trimmed.split(RegExp(r'\s+')).first;
}

String _normalize(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  return value
      .toLowerCase()
      .split('')
      .map((char) => replacements[char] ?? char)
      .join();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/platform/google_maps_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/glass_bottom_nav.dart';
import '../../../shared/widgets/segmented.dart';
import '../data/seller_routes_models.dart';
import '../data/seller_routes_repository.dart';

class SellerRoutesScreen extends ConsumerStatefulWidget {
  const SellerRoutesScreen({super.key});

  @override
  ConsumerState<SellerRoutesScreen> createState() => _SellerRoutesScreenState();
}

class _SellerRoutesScreenState extends ConsumerState<SellerRoutesScreen> {
  static const _depot = LatLng(27.4861, -99.5069);

  int _selectedIndex = 0;
  final Set<String> _selectedCandidateKeys = {};
  final Map<int, List<SellerRouteDelivery>> _draftOrders = {};
  int? _expandedRouteId;
  RoutePreview? _preview;
  bool _previewing = false;
  bool _savingRoute = false;
  int? _optimizingRouteId;
  int? _savingOrderRouteId;
  String? _feedback;

  final List<SegmentedItem> _tabs = const [
    SegmentedItem(label: 'Armar', icon: Symbols.add_road),
    SegmentedItem(label: 'Rutas', icon: Symbols.map),
    SegmentedItem(label: 'Historial', icon: Symbols.history),
  ];

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(sellerRoutesWorkspaceProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              RefreshIndicator(
                color: AppColors.neniDeep,
                onRefresh: () async {
                  ref.invalidate(sellerRoutesWorkspaceProvider);
                  await ref.read(sellerRoutesWorkspaceProvider.future);
                },
                child: workspaceAsync.when(
                  loading: _buildLoading,
                  error: (error, _) => _buildError(error),
                  data: _buildContent,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GlassBottomNav(
                  items: buildSellerNavItems(),
                  currentRoute: '/routes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        const _RouteSkeleton(),
        const SizedBox(height: 12),
        const _RouteSkeleton(),
      ],
    );
  }

  Widget _buildError(Object error) {
    final message = error is SellerRoutesException
        ? error.message
        : 'No pudimos cargar las rutas.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _EmptyState(
          icon: Symbols.wifi_off,
          title: 'Sin conexión con rutas',
          message: message,
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(sellerRoutesWorkspaceProvider),
        ),
      ],
    );
  }

  Widget _buildContent(SellerRoutesWorkspace workspace) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        _buildSummary(workspace),
        const SizedBox(height: 12),
        SegmentedControl(
          items: _tabs,
          selectedIndex: _selectedIndex,
          onChanged: (i) => setState(() => _selectedIndex = i),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 12),
          _FeedbackBanner(
            message: _feedback!,
            onClose: () => setState(() => _feedback = null),
          ),
        ],
        const SizedBox(height: 14),
        if (_selectedIndex == 0) _buildBuilder(workspace),
        if (_selectedIndex == 1) _buildOpenRoutes(workspace.openRoutes),
        if (_selectedIndex == 2) _buildHistory(workspace.historyRoutes),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rutas de reparto', style: AppTextStyles.display),
              const SizedBox(height: 4),
              Text(
                'Arma, optimiza y revisa recorridos con datos del API.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        _IconTile(
          icon: Symbols.sync,
          onTap: () => ref.invalidate(sellerRoutesWorkspaceProvider),
        ),
      ],
    );
  }

  Widget _buildSummary(SellerRoutesWorkspace workspace) {
    final selected = _selectedCandidates(workspace);
    final withCoords = workspace.candidates
        .where((c) => c.hasCoordinates)
        .length;
    final pendingMoney = workspace.candidates.fold<double>(
      0,
      (sum, c) => sum + c.total,
    );

    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: 'Candidatos',
            value: workspace.candidates.length.toString(),
            color: AppColors.neniDeep,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _KpiTile(
            label: 'Con mapa',
            value: withCoords.toString(),
            color: AppColors.statusDeliveredFg,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _KpiTile(
            label: 'Elegidos',
            value: selected.length.toString(),
            color: AppColors.statusRouteFg,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _KpiTile(
            label: 'Por ruta',
            value: routeMoney(pendingMoney),
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildBuilder(SellerRoutesWorkspace workspace) {
    final selected = _selectedCandidates(workspace);
    final noCoords = selected.where((c) => !c.hasCoordinates).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Pedidos y tandas disponibles',
          trailing: TextButton.icon(
            onPressed: workspace.candidates.isEmpty
                ? null
                : () => _selectAllCandidates(workspace),
            icon: const Icon(Symbols.checklist, size: 18),
            label: const Text('Seleccionar'),
          ),
        ),
        if (workspace.candidates.isEmpty)
          const _EmptyState(
            icon: Symbols.inventory_2,
            title: 'Sin entregas para ruta',
            message:
                'Cuando haya pedidos o tandas disponibles aparecerán aquí.',
          )
        else
          ...workspace.candidates.map(_buildCandidateCard),
        const SizedBox(height: 10),
        _BuilderActionBar(
          selectedCount: selected.length,
          noCoordsCount: noCoords,
          previewing: _previewing,
          saving: _savingRoute,
          onPreview: selected.isEmpty
              ? null
              : () => _previewSelected(workspace),
          onCreate: selected.isEmpty ? null : () => _createRoute(workspace),
          onClear: selected.isEmpty ? null : _clearSelection,
        ),
        if (_preview != null) ...[
          const SizedBox(height: 14),
          _PreviewCard(preview: _preview!, selectedCount: selected.length),
          const SizedBox(height: 12),
          _RouteMapCard(preview: _preview, depot: _depot),
        ],
      ],
    );
  }

  Widget _buildCandidateCard(RouteCandidate candidate) {
    final selected = _selectedCandidateKeys.contains(candidate.key);
    final address = candidate.address?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.softRadius,
          onTap: () => _toggleCandidate(candidate),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF5FA) : AppColors.surface,
              borderRadius: AppRadii.softRadius,
              border: Border.all(
                color: selected
                    ? AppColors.neni.withValues(alpha: 0.45)
                    : AppColors.line,
              ),
              boxShadow: AppShadows.small,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(initial: candidate.initial, selected: selected),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h2.copyWith(fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            candidate.subtitle ?? candidate.kind,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Symbols.check_circle : Symbols.add_circle,
                      color: selected ? AppColors.neniDeep : AppColors.ink3,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _TinyChip(label: candidate.kind, color: AppColors.neniDeep),
                    _TinyChip(
                      label: candidate.hasCoordinates
                          ? 'Con ubicación'
                          : 'Sin ubicación',
                      color: candidate.hasCoordinates
                          ? AppColors.statusDeliveredFg
                          : AppColors.statusPendingFg,
                    ),
                    if (candidate.total > 0)
                      _TinyChip(
                        label: routeMoney(candidate.total),
                        color: AppColors.statusRouteFg,
                      ),
                    if ((candidate.badge ?? '').trim().isNotEmpty)
                      _TinyChip(
                        label: candidate.badge!,
                        color: AppColors.lavender,
                      ),
                  ],
                ),
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Symbols.location_on,
                        size: 16,
                        color: AppColors.ink3,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenRoutes(List<SellerRoute> routes) {
    if (routes.isEmpty) {
      return const _EmptyState(
        icon: Symbols.route,
        title: 'No hay rutas abiertas',
        message: 'Las rutas pendientes o en reparto aparecerán aquí.',
      );
    }

    return Column(children: routes.map(_buildRouteCard).toList());
  }

  Widget _buildHistory(List<SellerRoute> routes) {
    if (routes.isEmpty) {
      return const _EmptyState(
        icon: Symbols.history,
        title: 'Sin historial todavía',
        message: 'Cuando cierres rutas, el resumen quedará guardado aquí.',
      );
    }

    return Column(children: routes.map(_buildRouteCard).toList());
  }

  Widget _buildRouteCard(SellerRoute route) {
    final expanded = _expandedRouteId == route.id;
    final draft = _draftOrders[route.id] ?? route.deliveries;
    final canManage = route.status != SellerRouteStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
                _RouteIcon(status: route.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name, style: AppTextStyles.h2),
                      const SizedBox(height: 2),
                      Text(
                        '${route.totalStops} paradas · ${routeMoney(route.totalAmount)}',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: route.status),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Pendientes',
                    value: route.pendingStops.toString(),
                    color: AppColors.statusPendingFg,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _MiniMetric(
                    label: 'Entregadas',
                    value: route.deliveredStops.toString(),
                    color: AppColors.statusDeliveredFg,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _MiniMetric(
                    label: 'Saldo',
                    value: routeMoney(route.balanceDue),
                    color: AppColors.neniDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: expanded ? 'Ocultar' : 'Detalle',
                    icon: expanded ? Symbols.expand_less : Symbols.expand_more,
                    onTap: () => _toggleRoute(route),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _SmallActionButton(
                    label: 'Mapa',
                    icon: Symbols.map,
                    onTap: route.hasMapPoints
                        ? () => _showRouteMap(route)
                        : null,
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: _SmallActionButton(
                      label: _optimizingRouteId == route.id
                          ? '...'
                          : 'Optimizar',
                      icon: Symbols.auto_awesome,
                      onTap: _optimizingRouteId == null
                          ? () => _optimizeRoute(route.id)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 13),
              _RouteMapCard(route: route, depot: _depot),
              const SizedBox(height: 13),
              ...List.generate(
                draft.length,
                (index) => _DeliveryRow(
                  delivery: draft[index],
                  canMove: canManage,
                  onUp: index == 0
                      ? null
                      : () => _moveDelivery(route, index, -1),
                  onDown: index == draft.length - 1
                      ? null
                      : () => _moveDelivery(route, index, 1),
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SmallActionButton(
                        label: _savingOrderRouteId == route.id
                            ? 'Guardando...'
                            : 'Guardar orden',
                        icon: Symbols.save,
                        filled: true,
                        onTap: _savingOrderRouteId == null
                            ? () => _saveOrder(route)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _SmallActionButton(
                        label: 'Eliminar',
                        icon: Symbols.delete,
                        danger: true,
                        onTap: () => _deleteRoute(route.id),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<RouteCandidate> _selectedCandidates(SellerRoutesWorkspace workspace) {
    return workspace.candidates
        .where((candidate) => _selectedCandidateKeys.contains(candidate.key))
        .toList();
  }

  void _toggleCandidate(RouteCandidate candidate) {
    setState(() {
      if (_selectedCandidateKeys.contains(candidate.key)) {
        _selectedCandidateKeys.remove(candidate.key);
      } else {
        _selectedCandidateKeys.add(candidate.key);
      }
      _preview = null;
    });
  }

  void _selectAllCandidates(SellerRoutesWorkspace workspace) {
    setState(() {
      _selectedCandidateKeys
        ..clear()
        ..addAll(workspace.candidates.map((c) => c.key));
      _preview = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCandidateKeys.clear();
      _preview = null;
    });
  }

  Future<void> _previewSelected(SellerRoutesWorkspace workspace) async {
    setState(() {
      _previewing = true;
      _feedback = null;
    });
    try {
      final preview = await ref
          .read(sellerRoutesRepositoryProvider)
          .previewRoute(_selectedCandidates(workspace));
      setState(() {
        _preview = preview;
        if (preview.skipped.isNotEmpty) {
          _feedback =
              '${preview.skipped.length} entrega(s) no entraron al cálculo.';
        }
      });
    } catch (e) {
      _setError(e, 'No pudimos calcular la ruta.');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _createRoute(SellerRoutesWorkspace workspace) async {
    setState(() {
      _savingRoute = true;
      _feedback = null;
    });
    try {
      await ref
          .read(sellerRoutesRepositoryProvider)
          .createRoute(_selectedCandidates(workspace));
      _selectedCandidateKeys.clear();
      _preview = null;
      ref.invalidate(sellerRoutesWorkspaceProvider);
      setState(() {
        _selectedIndex = 1;
        _feedback = 'Ruta creada con datos del API.';
      });
    } catch (e) {
      _setError(e, 'No pudimos crear la ruta.');
    } finally {
      if (mounted) setState(() => _savingRoute = false);
    }
  }

  Future<void> _optimizeRoute(int routeId) async {
    setState(() {
      _optimizingRouteId = routeId;
      _feedback = null;
    });
    try {
      await ref.read(sellerRoutesRepositoryProvider).optimizeRoute(routeId);
      ref.invalidate(sellerRoutesWorkspaceProvider);
      setState(() => _feedback = 'Ruta optimizada desde el API.');
    } catch (e) {
      _setError(e, 'No pudimos optimizar la ruta.');
    } finally {
      if (mounted) setState(() => _optimizingRouteId = null);
    }
  }

  Future<void> _saveOrder(SellerRoute route) async {
    final draft = _draftOrders[route.id] ?? route.deliveries;
    setState(() {
      _savingOrderRouteId = route.id;
      _feedback = null;
    });
    try {
      await ref
          .read(sellerRoutesRepositoryProvider)
          .reorderRoute(route.id, draft.map((d) => d.deliveryId).toList());
      _draftOrders.remove(route.id);
      ref.invalidate(sellerRoutesWorkspaceProvider);
      setState(() => _feedback = 'Orden de ruta guardado.');
    } catch (e) {
      _setError(e, 'No pudimos guardar el orden.');
    } finally {
      if (mounted) setState(() => _savingOrderRouteId = null);
    }
  }

  Future<void> _deleteRoute(int routeId) async {
    setState(() => _feedback = null);
    try {
      await ref.read(sellerRoutesRepositoryProvider).deleteRoute(routeId);
      _draftOrders.remove(routeId);
      if (_expandedRouteId == routeId) _expandedRouteId = null;
      ref.invalidate(sellerRoutesWorkspaceProvider);
      setState(() => _feedback = 'Ruta eliminada.');
    } catch (e) {
      _setError(e, 'No pudimos eliminar la ruta.');
    }
  }

  void _toggleRoute(SellerRoute route) {
    setState(() {
      if (_expandedRouteId == route.id) {
        _expandedRouteId = null;
      } else {
        _expandedRouteId = route.id;
        _draftOrders[route.id] = [...route.deliveries];
      }
    });
  }

  void _moveDelivery(SellerRoute route, int index, int direction) {
    final list = [...(_draftOrders[route.id] ?? route.deliveries)];
    final target = index + direction;
    if (target < 0 || target >= list.length) return;
    final item = list.removeAt(index);
    list.insert(target, item);
    setState(() => _draftOrders[route.id] = list);
  }

  void _showRouteMap(SellerRoute route) {
    setState(() {
      _expandedRouteId = route.id;
      _draftOrders[route.id] = [...route.deliveries];
    });
  }

  void _setError(Object error, String fallback) {
    final message = error is SellerRoutesException ? error.message : fallback;
    if (mounted) setState(() => _feedback = message);
  }
}

class _RouteMapCard extends ConsumerWidget {
  const _RouteMapCard({required this.depot, this.preview, this.route});

  final LatLng depot;
  final RoutePreview? preview;
  final SellerRoute? route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = _points();
    if (points.isEmpty) {
      return const _EmptyState(
        icon: Symbols.location_off,
        title: 'Sin coordenadas',
        message: 'Guarda la ubicación de las clientas para ver el mapa.',
      );
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('depot'),
        position: depot,
        infoWindow: const InfoWindow(title: 'Base'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      ...points.indexed.map(
        (entry) => Marker(
          markerId: MarkerId('stop-${entry.$1}'),
          position: entry.$2,
          infoWindow: InfoWindow(title: 'Parada ${entry.$1 + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        ),
      ),
    };

    final polylinePoints = _polylinePoints(points);
    final mapsConfigured = ref.watch(googleMapsConfiguredProvider);
    return mapsConfigured.when(
      loading: () => const _MapConfigState(
        icon: Symbols.map,
        title: 'Preparando mapa',
        message: 'Estamos revisando la configuracion de Google Maps.',
      ),
      error: (_, _) => const _MapConfigState(
        icon: Symbols.location_off,
        title: 'Mapa no disponible',
        message: 'No pudimos validar la configuracion de Google Maps.',
      ),
      data: (configured) {
        if (!configured) {
          return const _MapConfigState(
            icon: Symbols.location_off,
            title: 'Falta configurar Google Maps',
            message:
                'Agrega GOOGLE_MAPS_API_KEY o googleMapsApiKey para activar el mapa en Android.',
          );
        }

        return _GoogleRouteMap(
          points: points,
          markers: markers,
          polylinePoints: polylinePoints,
        );
      },
    );
  }

  List<LatLng> _points() {
    final previewStops =
        preview?.stops
            .where((s) => s.latitude != null && s.longitude != null)
            .map((s) => LatLng(s.latitude!, s.longitude!))
            .toList() ??
        const <LatLng>[];
    if (previewStops.isNotEmpty) return previewStops;

    return route?.deliveries
            .where((d) => d.latitude != null && d.longitude != null)
            .map((d) => LatLng(d.latitude!, d.longitude!))
            .toList() ??
        const <LatLng>[];
  }

  List<LatLng> _polylinePoints(List<LatLng> stops) {
    final encoded = preview?.polylineEncoded;
    if (encoded != null && encoded.isNotEmpty) return _decodePolyline(encoded);
    return [depot, ...stops];
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class _GoogleRouteMap extends StatelessWidget {
  const _GoogleRouteMap({
    required this.points,
    required this.markers,
    required this.polylinePoints,
  });

  final List<LatLng> points;
  final Set<Marker> markers;
  final List<LatLng> polylinePoints;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.softRadius,
      child: SizedBox(
        height: 240,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: points.first,
            zoom: 12.5,
          ),
          markers: markers,
          polylines: {
            if (polylinePoints.length > 1)
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylinePoints,
                color: AppColors.neniDeep,
                width: 5,
              ),
          },
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }
}

class _MapConfigState extends StatelessWidget {
  const _MapConfigState({
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
      height: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppColors.ink3),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.selectedCount});

  final RoutePreview preview;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5FA),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.neni.withValues(alpha: 0.18)),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.auto_awesome, color: AppColors.neniDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Previsualización', style: AppTextStyles.h2),
              ),
              _TinyChip(
                label: preview.optimizerSource.isEmpty
                    ? 'API'
                    : preview.optimizerSource,
                color: AppColors.lavender,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Paradas',
                  value: preview.stops.length.toString(),
                  color: AppColors.neniDeep,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MiniMetric(
                  label: 'Distancia',
                  value: preview.distanceLabel,
                  color: AppColors.statusRouteFg,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _MiniMetric(
                  label: 'Tiempo',
                  value: preview.durationLabel,
                  color: AppColors.statusDeliveredFg,
                ),
              ),
            ],
          ),
          if (preview.stopsWithoutCoords > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${preview.stopsWithoutCoords} entrega(s) sin coordenadas quedaron al final.',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11.5,
                color: AppColors.statusPendingFg,
              ),
            ),
          ],
          if (preview.stops.isEmpty && selectedCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'El API no encontró entregas válidas con la selección actual.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _BuilderActionBar extends StatelessWidget {
  const _BuilderActionBar({
    required this.selectedCount,
    required this.noCoordsCount,
    required this.previewing,
    required this.saving,
    required this.onPreview,
    required this.onCreate,
    required this.onClear,
  });

  final int selectedCount;
  final int noCoordsCount;
  final bool previewing;
  final bool saving;
  final VoidCallback? onPreview;
  final VoidCallback? onCreate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedCount == 0
                      ? 'Selecciona entregas para armar ruta'
                      : '$selectedCount entrega(s) seleccionadas',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (noCoordsCount > 0)
                _TinyChip(
                  label: '$noCoordsCount sin ubicación',
                  color: AppColors.statusPendingFg,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallActionButton(
                  label: previewing ? 'Calculando...' : 'Previsualizar',
                  icon: Symbols.route,
                  onTap: previewing || saving ? null : onPreview,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SmallActionButton(
                  label: saving ? 'Guardando...' : 'Guardar ruta',
                  icon: Symbols.save,
                  filled: true,
                  onTap: previewing || saving ? null : onCreate,
                ),
              ),
              const SizedBox(width: 9),
              _IconTile(
                icon: Symbols.close,
                onTap: previewing || saving ? null : onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.delivery,
    required this.canMove,
    this.onUp,
    this.onDown,
  });

  final SellerRouteDelivery delivery;
  final bool canMove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final address = delivery.effectiveAddress;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAFC),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: delivery.isClosed ? AppColors.ink3 : AppColors.neniDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                delivery.sortOrder.toString(),
                style: AppTextStyles.chip.copyWith(color: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    delivery.isTanda ? 'Tanda' : 'Pedido',
                    delivery.status.label,
                    if (address != null && address.trim().isNotEmpty) address,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10.8),
                ),
              ],
            ),
          ),
          if (canMove) ...[
            _MoveButton(icon: Symbols.keyboard_arrow_up, onTap: onUp),
            const SizedBox(width: 4),
            _MoveButton(icon: Symbols.keyboard_arrow_down, onTap: onDown),
          ],
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
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
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.eyebrow(AppColors.ink3).copyWith(fontSize: 8),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h2.copyWith(fontSize: 15, color: color),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow(AppColors.ink3).copyWith(fontSize: 8),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SellerRouteStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SellerRouteStatus.pending => AppColors.statusPendingFg,
      SellerRouteStatus.active => AppColors.statusRouteFg,
      SellerRouteStatus.completed => AppColors.statusDeliveredFg,
      SellerRouteStatus.canceled => AppColors.liveRed,
    };

    return _TinyChip(label: status.label, color: color);
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.chip.copyWith(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = filled
        ? AppColors.neniDeep
        : danger
        ? const Color(0xFFFFF1F4)
        : AppColors.surface;
    final fg = filled
        ? AppColors.surface
        : danger
        ? AppColors.liveRed
        : AppColors.neniDeep;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: filled ? null : Border.all(color: AppColors.line),
              boxShadow: filled
                  ? AppShadows.brandSmall(AppColors.neniDeep)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: fg,
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

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
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
              boxShadow: AppShadows.small,
            ),
            child: Icon(icon, color: AppColors.ink, size: 22),
          ),
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _IconTile(icon: icon, onTap: onTap);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.selected});

  final String initial;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? const [AppColors.neni, AppColors.neniDeep]
              : const [Color(0xFFB79BF0), AppColors.lavender],
        ),
        borderRadius: AppRadii.avatarRadius,
        boxShadow: AppShadows.small,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.h2.copyWith(
            color: AppColors.surface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RouteIcon extends StatelessWidget {
  const _RouteIcon({required this.status});

  final SellerRouteStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      SellerRouteStatus.pending => Symbols.route,
      SellerRouteStatus.active => Symbols.sensors,
      SellerRouteStatus.completed => Symbols.check_circle,
      SellerRouteStatus.canceled => Symbols.cancel,
    };

    final color = switch (status) {
      SellerRouteStatus.pending => AppColors.statusPendingFg,
      SellerRouteStatus.active => AppColors.statusRouteFg,
      SellerRouteStatus.completed => AppColors.statusDeliveredFg,
      SellerRouteStatus.canceled => AppColors.liveRed,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.iconBtnRadius,
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
          ),
          ?trailing,
        ],
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
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.neniDeep, size: 34),
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
            _SmallActionButton(
              label: actionLabel!,
              icon: Symbols.refresh,
              filled: true,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.info, color: AppColors.gold, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.subtitle.copyWith(
                color: const Color(0xFF9B6200),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Symbols.close, size: 18),
            color: const Color(0xFF9B6200),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _RouteSkeleton extends StatelessWidget {
  const _RouteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
      ),
    );
  }
}

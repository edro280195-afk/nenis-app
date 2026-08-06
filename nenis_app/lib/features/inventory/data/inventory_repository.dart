import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import '../../labels/data/label_print_models.dart';
import '../../labels/data/label_template_models.dart';
import 'inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this._dio);
  final Dio _dio;
  Future<List<InventoryBoxSummary>> getBoxes([String? search]) async {
    final response = await _dio.get(
      '/api/inventory/boxes',
      queryParameters: search == null || search.trim().isEmpty
          ? null
          : {'search': search.trim()},
    );
    return ((response.data as List?) ?? const [])
        .map(
          (item) => InventoryBoxSummary.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<InventoryBox> getBox(String id) async =>
      _box(await _dio.get('/api/inventory/boxes/$id'));
  Future<InventoryBox> getBoxByToken(String token) async =>
      _box(await _dio.get('/api/inventory/boxes/by-token/$token'));
  Future<InventoryBox> createBox({
    required String code,
    required String name,
    String? location,
  }) async => _box(
    await _dio.post(
      '/api/inventory/boxes',
      data: {'code': code, 'name': name, 'location': location},
    ),
  );
  Future<InventoryBox> updateBox(
    String boxId, {
    required String code,
    required String name,
    String? location,
  }) async => _box(
    await _dio.put(
      '/api/inventory/boxes/$boxId',
      data: {'code': code, 'name': name, 'location': location},
    ),
  );
  Future<InventoryBox> addItem(
    String boxId, {
    required String name,
    String? variant,
    String? barcode,
    required int quantity,
    String? note,
  }) async => _box(
    await _dio.post(
      '/api/inventory/boxes/$boxId/items',
      data: {
        'name': name,
        'variant': variant,
        'barcode': barcode,
        'quantity': quantity,
        'note': note,
      },
    ),
  );
  Future<InventoryBox> adjustItem(
    String itemId,
    int quantityDelta, {
    String? note,
  }) async => _box(
    await _dio.post(
      '/api/inventory/items/$itemId/adjust',
      data: {'quantityDelta': quantityDelta, 'note': note},
    ),
  );
  Future<InventoryBox> bindNfc(String boxId, String tagUid) async => _box(
    await _dio.post(
      '/api/inventory/boxes/$boxId/bind-nfc',
      data: {'tagUid': tagUid},
    ),
  );
  Future<InventoryLabelPrint> createLabelPrint({
    required LabelTemplateKind kind,
    required String targetId,
    required LabelMediaSize mediaSize,
    int copies = 1,
  }) async {
    final response = await _dio.post(
      '/api/inventory/label-prints',
      data: {
        'kind': kind.api,
        'targetId': targetId,
        'mediaSize': mediaSize.api,
        'copies': copies,
        'output': 'SystemPrint',
      },
    );
    return InventoryLabelPrint.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  Future<void> updateLabelPrintStatus(
    String id,
    String status, {
    String? failureReason,
  }) async {
    await _dio.put(
      '/api/inventory/label-prints/$id/status',
      data: {'status': status, 'failureReason': failureReason},
    );
  }

  Future<InventoryBox> transfer({
    required String sourceBoxId,
    required String destinationBoxId,
    required String itemId,
    required int quantity,
    String? note,
  }) async => _box(
    await _dio.post(
      '/api/inventory/transfers',
      data: {
        'sourceBoxId': sourceBoxId,
        'destinationBoxId': destinationBoxId,
        'itemId': itemId,
        'quantity': quantity,
        'note': note,
      },
    ),
  );
  Future<InventoryBox> completeCount(
    String boxId,
    List<Map<String, Object>> items, {
    String? note,
  }) async => _box(
    await _dio.post(
      '/api/inventory/boxes/$boxId/counts',
      data: {'items': items, 'note': note},
    ),
  );

  Future<InventoryMovementPage> getBoxMovements(
    String boxId, {
    int page = 1,
    int pageSize = 30,
    String? type,
  }) async {
    final response = await _dio.get(
      '/api/inventory/boxes/$boxId/movements',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return InventoryMovementPage.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  InventoryBox _box(Response<dynamic> response) =>
      InventoryBox.fromJson((response.data as Map).cast<String, dynamic>());
}

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.read(dioProvider)),
);
final inventoryBoxesProvider =
    FutureProvider.autoDispose<List<InventoryBoxSummary>>(
      (ref) => ref.read(inventoryRepositoryProvider).getBoxes(),
    );
final inventoryBoxProvider = FutureProvider.autoDispose
    .family<InventoryBox, String>(
      (ref, boxId) => ref.read(inventoryRepositoryProvider).getBox(boxId),
    );

/// Entrada de la bitácora: el movimiento junto con el código de la caja.
typedef InventoryLogEntry = ({String boxCode, InventoryMovement movement});

/// Parámetro para la consulta de la bitácora.
typedef InventoryLogQuery = ({String? boxId, String? boxCode});

class InventoryLogState {
  const InventoryLogState({
    this.entries = const [],
    this.hasMore = false,
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<InventoryLogEntry> entries;
  final bool hasMore;
  final int total;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  InventoryLogState copyWith({
    List<InventoryLogEntry>? entries,
    bool? hasMore,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
  }) {
    return InventoryLogState(
      entries: entries ?? this.entries,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

class InventoryLogNotifier extends Notifier<InventoryLogState> {
  InventoryLogNotifier(this._query);

  final InventoryLogQuery _query;

  @override
  InventoryLogState build() {
    _loadInitial();
    return const InventoryLogState(isLoading: true);
  }

  Future<void> refresh() async {
    state = const InventoryLogState(isLoading: true);
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final boxId = _query.boxId;
    final boxCode = _query.boxCode ?? 'B-??';
    try {
      if (boxId != null) {
        final page = await repo.getBoxMovements(boxId, page: 1, pageSize: 30);
        final entries = page.items
            .map((m) => (boxCode: boxCode, movement: m))
            .toList();
        state = InventoryLogState(
          entries: entries,
          hasMore: page.hasMore,
          total: page.total,
          page: 1,
          isLoading: false,
        );
      } else {
        final summaries = await repo.getBoxes();
        final entries = <InventoryLogEntry>[];
        for (final summary in summaries) {
          var pageNum = 1;
          while (true) {
            final page = await repo.getBoxMovements(
              summary.id,
              page: pageNum,
              pageSize: 50,
            );
            for (final m in page.items) {
              entries.add((boxCode: summary.code, movement: m));
            }
            if (!page.hasMore) break;
            pageNum += 1;
          }
        }
        entries.sort(
          (a, b) => b.movement.occurredAt.compareTo(a.movement.occurredAt),
        );
        state = InventoryLogState(
          entries: entries,
          hasMore: false,
          total: entries.length,
          page: 1,
          isLoading: false,
        );
      }
    } catch (e) {
      state = InventoryLogState(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.isLoading || current.isLoadingMore || !current.hasMore) return;
    final boxId = _query.boxId;
    if (boxId == null) return;

    final nextPage = current.page + 1;
    state = current.copyWith(isLoadingMore: true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final page = await repo.getBoxMovements(
        boxId,
        page: nextPage,
        pageSize: 30,
      );
      final newEntries = page.items
          .map((m) => (boxCode: _query.boxCode ?? 'B-??', movement: m))
          .toList();
      state = current.copyWith(
        entries: [...current.entries, ...newEntries],
        hasMore: page.hasMore,
        total: page.total,
        page: nextPage,
        isLoadingMore: false,
      );
    } catch (e) {
      state = current.copyWith(isLoadingMore: false, error: e);
    }
  }
}

final inventoryLogProvider = NotifierProvider.autoDispose
    .family<InventoryLogNotifier, InventoryLogState, InventoryLogQuery>(
      (arg) => InventoryLogNotifier(arg),
    );

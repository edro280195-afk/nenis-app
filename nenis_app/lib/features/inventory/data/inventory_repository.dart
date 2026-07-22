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

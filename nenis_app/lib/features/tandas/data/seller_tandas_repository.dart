import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_tandas_models.dart';

class SellerTandasException implements Exception {
  SellerTandasException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _friendly(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is String && data.trim().isNotEmpty) return data;
  }
  return fallback;
}

class SellerTandasRepository {
  SellerTandasRepository(this._dio);

  final Dio _dio;

  Future<List<SellerTanda>> getTandas() async {
    try {
      final res = await _dio.get('/api/tanda');
      return ((res.data as List?) ?? const [])
          .map((item) => SellerTanda.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos cargar tus tandas.'),
      );
    }
  }

  Future<SellerTanda> getTanda(String id) async {
    try {
      final res = await _dio.get('/api/tanda/$id');
      return SellerTanda.fromJson(res.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos abrir esta tanda.'),
      );
    }
  }

  Future<List<SellerTandaProduct>> getProducts() async {
    try {
      final res = await _dio.get('/api/tanda/products');
      return ((res.data as List?) ?? const [])
          .map(
            (item) => SellerTandaProduct.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos cargar los productos de tanda.'),
      );
    }
  }

  Future<List<SellerTandaClient>> getClients() async {
    try {
      final res = await _dio.get('/api/clients');
      return ((res.data as List?) ?? const [])
          .map(
            (item) => SellerTandaClient.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos cargar las clientas.'),
      );
    }
  }

  Future<SellerTanda> createTanda(CreateTandaRequest request) async {
    try {
      final res = await _dio.post('/api/tanda', data: request.toJson());
      return SellerTanda.fromJson(res.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos crear la tanda.'),
      );
    }
  }

  Future<SellerTandaProduct> createProduct({
    required String name,
    double basePrice = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/api/tanda/products',
        data: {'name': name.trim(), 'basePrice': basePrice},
      );
      return SellerTandaProduct.fromJson(res.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos crear el producto de tanda.'),
      );
    }
  }

  Future<SellerTanda> updateTanda(UpdateTandaRequest request) async {
    try {
      final res = await _dio.put(
        '/api/tanda/${request.id}',
        data: request.toJson(),
      );
      return SellerTanda.fromJson(res.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos actualizar la tanda.'),
      );
    }
  }

  Future<void> addParticipant(AddTandaParticipantRequest request) async {
    try {
      await _dio.post('/api/tanda/participants', data: request.toJson());
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos inscribir a la clienta.'),
      );
    }
  }

  Future<void> updateParticipantTurn({
    required String participantId,
    required int newTurn,
  }) async {
    try {
      await _dio.patch(
        '/api/tanda/participants/$participantId/turn',
        data: {'newTurn': newTurn},
      );
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos cambiar el turno.'),
      );
    }
  }

  Future<void> updateParticipantVariant({
    required String participantId,
    required String? variant,
  }) async {
    try {
      await _dio.patch(
        '/api/tanda/participants/$participantId/variant',
        data: {'variant': variant?.trim()},
      );
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos actualizar la variante.'),
      );
    }
  }

  Future<void> removeParticipant(String participantId) async {
    try {
      await _dio.delete('/api/tanda/participants/$participantId');
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos retirar a la participante.'),
      );
    }
  }

  Future<void> reorderParticipants({
    required String tandaId,
    required List<String> participantIds,
  }) async {
    try {
      await _dio.post(
        '/api/tanda/$tandaId/reorder',
        data: {'participantIds': participantIds},
      );
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos guardar el nuevo orden.'),
      );
    }
  }

  Future<void> registerPayment({
    required String participantId,
    required int weekNumber,
    required double amountPaid,
    required double penaltyPaid,
  }) async {
    try {
      await _dio.post(
        '/api/tanda/payments',
        data: {
          'participantId': participantId,
          'weekNumber': weekNumber,
          'amountPaid': amountPaid,
          'penaltyPaid': penaltyPaid,
          'notes': "Registrado desde Neni's App",
        },
      );
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos registrar el pago.'),
      );
    }
  }

  Future<void> deletePayment(String paymentId) async {
    try {
      await _dio.delete('/api/tanda/payments/$paymentId');
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos quitar el pago.'),
      );
    }
  }

  Future<void> confirmDelivery(String participantId) async {
    try {
      await _dio.patch(
        '/api/tanda/participants/$participantId/confirm-delivery',
      );
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos confirmar la entrega.'),
      );
    }
  }

  Future<void> processPenalties(String tandaId) async {
    try {
      await _dio.post('/api/tanda/$tandaId/process-penalties', data: {});
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos procesar atrasos.'),
      );
    }
  }

  Future<Map<String, dynamic>> getWhatsAppReminder(
    String participantId, {
    int? weekNumber,
  }) async {
    try {
      final res = await _dio.get(
        '/api/tanda/participants/$participantId/whatsapp-reminder',
        queryParameters: weekNumber != null ? {'weekNumber': weekNumber} : null,
      );
      return res.data as Map<String, dynamic>;
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos obtener el mensaje de WhatsApp.'),
      );
    }
  }

  Future<SellerTanda> drawTurns(String tandaId) async {
    try {
      final res = await _dio.post('/api/tanda/$tandaId/draw-turns');
      return SellerTanda.fromJson(res.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerTandasException(
        _friendly(error, 'No pudimos realizar el sorteo de turnos.'),
      );
    }
  }
}


final sellerTandasRepositoryProvider = Provider<SellerTandasRepository>((ref) {
  return SellerTandasRepository(ref.read(dioProvider));
});

class SellerTandasController extends AsyncNotifier<SellerTandasWorkspace> {
  @override
  Future<SellerTandasWorkspace> build() => _loadWorkspace();

  Future<SellerTandasWorkspace> _loadWorkspace({String? selectedId}) async {
    final repo = ref.read(sellerTandasRepositoryProvider);
    final summaries = await repo.getTandas();
    final tandas = await Future.wait(
      summaries.map((tanda) => repo.getTanda(tanda.id)),
    );
    final products = await repo.getProducts();
    final clients = await repo.getClients();
    final resolvedId =
        selectedId ?? (tandas.isNotEmpty ? tandas.first.id : null);
    final detail = resolvedId == null || tandas.isEmpty
        ? null
        : tandas.firstWhere(
            (tanda) => tanda.id == resolvedId,
            orElse: () => tandas.first,
          );
    return SellerTandasWorkspace(
      tandas: tandas,
      products: products,
      clients: clients,
      selectedId: resolvedId,
      selectedDetail: detail,
    );
  }

  Future<void> reload() async {
    final selectedId = state.asData?.value.selectedId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadWorkspace(selectedId: selectedId),
    );
  }

  Future<void> selectTanda(String id) async {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        selectedId: id,
        clearSelectedDetail: true,
        detailLoading: true,
      ),
    );
    final repo = ref.read(sellerTandasRepositoryProvider);
    state = await AsyncValue.guard(() async {
      final detail = await repo.getTanda(id);
      return state.asData?.value.copyWith(
            selectedId: id,
            selectedDetail: detail,
            detailLoading: false,
          ) ??
          current.copyWith(
            selectedId: id,
            selectedDetail: detail,
            detailLoading: false,
          );
    });
  }

  Future<void> createTanda(CreateTandaRequest request) async {
    final repo = ref.read(sellerTandasRepositoryProvider);
    final created = await repo.createTanda(request);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadWorkspace(selectedId: created.id),
    );
  }

  Future<void> createProduct({
    required String name,
    double basePrice = 0,
  }) async {
    final repo = ref.read(sellerTandasRepositoryProvider);
    await repo.createProduct(name: name, basePrice: basePrice);
    await reload();
  }

  Future<void> updateTanda(UpdateTandaRequest request) async {
    final repo = ref.read(sellerTandasRepositoryProvider);
    await repo.updateTanda(request);
    await reloadSelected(request.id);
  }

  Future<void> addParticipant(AddTandaParticipantRequest request) async {
    final repo = ref.read(sellerTandasRepositoryProvider);
    await repo.addParticipant(request);
    await reloadSelected(request.tandaId);
  }

  Future<void> updateParticipantTurn({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
    required int newTurn,
  }) async {
    await ref
        .read(sellerTandasRepositoryProvider)
        .updateParticipantTurn(participantId: participant.id, newTurn: newTurn);
    await reloadSelected(tanda.id);
  }

  Future<void> updateParticipantVariant({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
    required String? variant,
  }) async {
    await ref
        .read(sellerTandasRepositoryProvider)
        .updateParticipantVariant(
          participantId: participant.id,
          variant: variant,
        );
    await reloadSelected(tanda.id);
  }

  Future<void> removeParticipant({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
  }) async {
    await ref
        .read(sellerTandasRepositoryProvider)
        .removeParticipant(participant.id);
    await reloadSelected(tanda.id);
  }

  Future<void> reorderParticipants({
    required SellerTanda tanda,
    required List<String> participantIds,
  }) async {
    await ref
        .read(sellerTandasRepositoryProvider)
        .reorderParticipants(tandaId: tanda.id, participantIds: participantIds);
    await reloadSelected(tanda.id);
  }

  Future<void> registerPayment({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
  }) async {
    final week = tanda.actionableWeek;
    if (week == 0) {
      throw SellerTandasException('Esta tanda no tiene una semana cobrable.');
    }
    await ref
        .read(sellerTandasRepositoryProvider)
        .registerPayment(
          participantId: participant.id,
          weekNumber: week,
          amountPaid: participant.amountFor(tanda),
          penaltyPaid: participant.isLate ? tanda.penaltyAmount : 0,
        );
    await reloadSelected(tanda.id);
  }

  Future<void> deleteCurrentPayment({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
  }) async {
    final week = tanda.actionableWeek;
    final payment = participant.paymentForWeek(week);
    if (payment == null) {
      throw SellerTandasException('No hay pago registrado para esta semana.');
    }
    await ref.read(sellerTandasRepositoryProvider).deletePayment(payment.id);
    await reloadSelected(tanda.id);
  }

  Future<void> confirmDelivery({
    required SellerTanda tanda,
    required SellerTandaParticipant participant,
  }) async {
    await ref
        .read(sellerTandasRepositoryProvider)
        .confirmDelivery(participant.id);
    await reloadSelected(tanda.id);
  }

  Future<void> processPenalties(SellerTanda tanda) async {
    await ref.read(sellerTandasRepositoryProvider).processPenalties(tanda.id);
    await reloadSelected(tanda.id);
  }

  Future<void> drawTurns(SellerTanda tanda) async {
    await ref.read(sellerTandasRepositoryProvider).drawTurns(tanda.id);
    await reloadSelected(tanda.id);
  }


  Future<void> reloadSelected(String selectedId) async {
    final current = state.asData?.value;
    if (current == null) {
      await reload();
      return;
    }
    final repo = ref.read(sellerTandasRepositoryProvider);
    final detail = await repo.getTanda(selectedId);
    final summaries = await repo.getTandas();
    final tandas = await Future.wait(
      summaries.map(
        (tanda) => tanda.id == selectedId
            ? Future.value(detail)
            : repo.getTanda(tanda.id),
      ),
    );
    state = AsyncData(
      current.copyWith(
        tandas: tandas,
        selectedId: selectedId,
        selectedDetail: detail,
        detailLoading: false,
      ),
    );
  }
}

final sellerTandasControllerProvider =
    AsyncNotifierProvider<SellerTandasController, SellerTandasWorkspace>(
      SellerTandasController.new,
    );

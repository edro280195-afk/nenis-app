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

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_clients_models.dart';

class SellerClientsException implements Exception {
  SellerClientsException(this.message);
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
    if (error.response?.statusCode == 403) {
      return 'Esta opción no está disponible para tu plan o permisos actuales.';
    }
  }
  return fallback;
}

class SellerClientsRepository {
  SellerClientsRepository(this._dio);

  final Dio _dio;

  Future<List<SellerClientProfile>> getClients() async {
    try {
      final response = await _dio.get('/api/clients');
      return ((response.data as List?) ?? const [])
          .map(
            (value) =>
                SellerClientProfile.fromJson(value as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos cargar las clientas.'),
      );
    }
  }

  Future<SellerClientProfile> getClient(int id) async {
    try {
      final response = await _dio.get('/api/clients/$id');
      return SellerClientProfile.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos abrir la clienta.'),
      );
    }
  }

  Future<void> updateClient(int id, UpdateSellerClientRequest request) async {
    try {
      await _dio.put('/api/clients/$id', data: request.toJson());
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos guardar la clienta.'),
      );
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      await _dio.delete('/api/clients/$id');
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos eliminar la clienta.'),
      );
    }
  }

  Future<List<SellerClientAlias>> getAliases(int clientId) async {
    try {
      final response = await _dio.get('/api/clients/$clientId/aliases');
      return ((response.data as List?) ?? const [])
          .map(
            (value) =>
                SellerClientAlias.fromJson(value as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos cargar los alias.'),
      );
    }
  }

  Future<SellerClientAlias> addAlias(int clientId, String alias) async {
    try {
      final response = await _dio.post(
        '/api/clients/$clientId/aliases',
        data: {'alias': alias.trim(), 'source': 'ManualConfirm'},
      );
      return SellerClientAlias.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos agregar el alias.'),
      );
    }
  }

  Future<void> deleteAlias(int aliasId) async {
    try {
      await _dio.delete('/api/clients/aliases/$aliasId');
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos borrar el alias.'),
      );
    }
  }

  Future<SellerClientLoyaltySummary> getLoyaltySummary(int clientId) async {
    try {
      final response = await _dio.get('/api/loyalty/$clientId');
      return SellerClientLoyaltySummary.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos cargar RegiPuntos.'),
      );
    }
  }

  Future<List<SellerClientLoyaltyTransaction>> getLoyaltyHistory(
    int clientId,
  ) async {
    try {
      final response = await _dio.get('/api/loyalty/$clientId/history');
      return ((response.data as List?) ?? const [])
          .map(
            (value) => SellerClientLoyaltyTransaction.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos cargar el historial de puntos.'),
      );
    }
  }

  Future<SellerClientInsight> getClientInsight(int clientId) async {
    try {
      final response = await _dio.get('/api/cami/client-insight/$clientId');
      return SellerClientInsight.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos generar el análisis de C.A.M.I.'),
      );
    }
  }

  Future<List<BulkGeocodeResult>> bulkGeocode(List<int> clientIds) async {
    if (clientIds.isEmpty) return const [];
    try {
      final response = await _dio.post(
        '/api/clients/bulk-geocode',
        data: {'clientIds': clientIds},
      );
      return ((response.data as List?) ?? const [])
          .map(
            (value) =>
                BulkGeocodeResult.fromJson(value as Map<String, dynamic>),
          )
          .toList();
    } catch (error) {
      throw SellerClientsException(
        _friendly(error, 'No pudimos ubicar las direcciones.'),
      );
    }
  }
}

final sellerClientsRepositoryProvider = Provider<SellerClientsRepository>((
  ref,
) {
  return SellerClientsRepository(ref.read(dioProvider));
});

final sellerClientsProvider =
    FutureProvider.autoDispose<List<SellerClientProfile>>((ref) {
      return ref.read(sellerClientsRepositoryProvider).getClients();
    });

final sellerClientDetailProvider = FutureProvider.autoDispose
    .family<SellerClientProfile, int>((ref, id) {
      return ref.read(sellerClientsRepositoryProvider).getClient(id);
    });

final sellerClientAliasesProvider = FutureProvider.autoDispose
    .family<List<SellerClientAlias>, int>((ref, id) {
      return ref.read(sellerClientsRepositoryProvider).getAliases(id);
    });

final sellerClientLoyaltyProvider = FutureProvider.autoDispose
    .family<SellerClientLoyaltySummary, int>((ref, id) {
      return ref.read(sellerClientsRepositoryProvider).getLoyaltySummary(id);
    });

final sellerClientLoyaltyHistoryProvider = FutureProvider.autoDispose
    .family<List<SellerClientLoyaltyTransaction>, int>((ref, id) {
      return ref.read(sellerClientsRepositoryProvider).getLoyaltyHistory(id);
    });

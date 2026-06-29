import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'addresses_models.dart';

class AddressesException implements Exception {
  AddressesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AddressesRepository {
  AddressesRepository(this._dio);

  final Dio _dio;

  Future<List<BuyerAddress>> getMyAddresses() async {
    try {
      final res = await _dio.get('/api/me/addresses');
      final list = (res.data as List?) ?? const [];
      return list
          .map((e) => BuyerAddress.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      throw AddressesException('No pudimos cargar tus direcciones.');
    } catch (_) {
      throw AddressesException('No pudimos cargar tus direcciones.');
    }
  }

  Future<BuyerAddress> updateAddress(int clientId, UpdateAddressRequest request) async {
    try {
      final res = await _dio.put(
        '/api/me/addresses/$clientId',
        data: request.toJson(),
      );
      return BuyerAddress.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw AddressesException('Esta dirección no está en tu cuenta.');
      }
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'No pudimos guardar la dirección.';
      throw AddressesException(message);
    } catch (_) {
      throw AddressesException('No pudimos guardar la dirección.');
    }
  }
}

final addressesRepositoryProvider = Provider<AddressesRepository>((ref) {
  return AddressesRepository(ref.read(dioProvider));
});

final addressesFeedProvider =
    FutureProvider.autoDispose<List<BuyerAddress>>((ref) {
  return ref.read(addressesRepositoryProvider).getMyAddresses();
});

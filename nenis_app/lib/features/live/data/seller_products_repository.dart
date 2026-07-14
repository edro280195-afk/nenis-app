import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'live_models.dart';

class SellerProductsException implements Exception {
  SellerProductsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SellerProductsRepository {
  SellerProductsRepository(this._dio);

  final Dio _dio;

  Future<List<SellerProduct>> getProducts() async {
    try {
      final res = await _dio.get('/api/business/products');
      return ((res.data as List?) ?? const [])
          .map((e) => SellerProduct.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (_) {
      throw SellerProductsException('No pudimos cargar tu catálogo.');
    }
  }
}

final sellerProductsRepositoryProvider = Provider<SellerProductsRepository>((ref) {
  return SellerProductsRepository(ref.read(dioProvider));
});

final sellerProductsProvider =
    FutureProvider.autoDispose<List<SellerProduct>>((ref) {
  return ref.read(sellerProductsRepositoryProvider).getProducts();
});

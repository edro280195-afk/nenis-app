import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'home_models.dart';

class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<BuyerHome> getHome() async {
    final res = await _dio.get('/api/me/home');
    return BuyerHome.fromJson(res.data as Map<String, dynamic>);
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.read(dioProvider));
});

final homeFeedProvider = FutureProvider.autoDispose<BuyerHome>((ref) {
  return ref.read(homeRepositoryProvider).getHome();
});

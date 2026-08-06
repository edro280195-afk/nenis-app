import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_provider.dart';

class GoogleAddressSuggestion {
  const GoogleAddressSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
  });

  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;

  factory GoogleAddressSuggestion.fromJson(Map<String, dynamic> json) {
    return GoogleAddressSuggestion(
      placeId: (json['placeId'] ?? '') as String,
      mainText: (json['mainText'] ?? '') as String,
      secondaryText: (json['secondaryText'] ?? '') as String,
      description: (json['description'] ?? '') as String,
    );
  }
}

class GoogleAddressSelection {
  const GoogleAddressSelection({
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;
}

class GoogleAddressRepository {
  GoogleAddressRepository(this._dio);

  final Dio _dio;

  Future<List<GoogleAddressSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
  }) async {
    try {
      final queryParameters = <String, String>{'input': input.trim()};
      if (sessionToken != null) {
        queryParameters['sessionToken'] = sessionToken;
      }
      final response = await _dio.get(
        '/api/clients/address-suggestions',
        queryParameters: queryParameters,
      );
      return ((response.data as List?) ?? const [])
          .whereType<Map>()
          .map(
            (value) => GoogleAddressSuggestion.fromJson(
              value.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException {
      return const [];
    }
  }

  Future<GoogleAddressSelection?> getDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final queryParameters = <String, String>{'placeId': placeId};
      if (sessionToken != null) {
        queryParameters['sessionToken'] = sessionToken;
      }
      final response = await _dio.get(
        '/api/clients/address-details',
        queryParameters: queryParameters,
      );
      final data = response.data as Map<String, dynamic>;
      return GoogleAddressSelection(
        address: (data['formattedAddress'] ?? '') as String,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
      );
    } on DioException {
      return null;
    }
  }
}

final googleAddressRepositoryProvider = Provider<GoogleAddressRepository>(
  (ref) => GoogleAddressRepository(ref.read(dioProvider)),
);

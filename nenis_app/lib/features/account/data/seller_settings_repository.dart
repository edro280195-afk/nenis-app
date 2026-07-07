import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_provider.dart';
import 'seller_settings_models.dart';

class SellerSettingsException implements Exception {
  SellerSettingsException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SellerSettingsRepository {
  SellerSettingsRepository(this._dio);

  final Dio _dio;

  Future<SellerBusinessSettings> getBusinessSettings() async {
    try {
      final res = await _dio.get('/api/business/me');
      return SellerBusinessSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos cargar la configuración del negocio.'),
      );
    }
  }

  Future<SellerBrandSettings> updateBrand({
    required String name,
    required String primaryColor,
    String? accentColor,
  }) async {
    try {
      final res = await _dio.put(
        '/api/business/brand',
        data: {
          'name': name.trim(),
          'brandPrimaryColor': primaryColor.trim(),
          'brandAccentColor': accentColor?.trim() ?? '',
        },
      );
      return SellerBrandSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos guardar el perfil de la tienda.'),
      );
    }
  }

  Future<MercadoPagoSettings> getPaymentSettings() async {
    try {
      final res = await _dio.get('/api/business/payment-settings');
      return MercadoPagoSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos cargar los métodos de pago.'),
      );
    }
  }

  Future<MercadoPagoSettings> updatePaymentSettings({
    required String publicKey,
    String? accessToken,
    bool clearAccessToken = false,
  }) async {
    try {
      final res = await _dio.put(
        '/api/business/payment-settings',
        data: {
          'publicKey': publicKey.trim(),
          'accessToken': accessToken?.trim(),
          'clearAccessToken': clearAccessToken,
        },
      );
      return MercadoPagoSettings.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos guardar los métodos de pago.'),
      );
    }
  }

  Future<List<SellerPayoutAccount>> getPayoutAccounts() async {
    try {
      final res = await _dio.get('/api/business/payout-accounts');
      return ((res.data as List?) ?? const [])
          .map(
            (item) => SellerPayoutAccount.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos cargar las cuentas bancarias.'),
      );
    }
  }

  Future<SellerPayoutAccount> createPayoutAccount({
    required SellerPayoutAccountKind kind,
    required String holderName,
    required String accountNumber,
    String? bankName,
    String? alias,
    String? notes,
    bool isDefault = false,
  }) async {
    try {
      final res = await _dio.post(
        '/api/business/payout-accounts',
        data: {
          'kind': kind.apiValue,
          'holderName': holderName.trim(),
          'accountNumber': accountNumber.trim(),
          'bankName': bankName?.trim(),
          'alias': alias?.trim(),
          'notes': notes?.trim(),
          'isDefault': isDefault,
        },
      );
      return SellerPayoutAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos agregar la cuenta bancaria.'),
      );
    }
  }

  Future<SellerPayoutAccount> updatePayoutAccount({
    required int id,
    SellerPayoutAccountKind? kind,
    String? holderName,
    String? accountNumber,
    String? bankName,
    String? alias,
    String? notes,
    bool? isDefault,
  }) async {
    try {
      final data = <String, Object?>{
        if (kind != null) 'kind': kind.apiValue,
        if (holderName != null) 'holderName': holderName.trim(),
        if (accountNumber != null) 'accountNumber': accountNumber.trim(),
        if (bankName != null) 'bankName': bankName.trim(),
        if (alias != null) 'alias': alias.trim(),
        if (notes != null) 'notes': notes.trim(),
        'isDefault': ?isDefault,
      };
      final res = await _dio.put(
        '/api/business/payout-accounts/$id',
        data: data,
      );
      return SellerPayoutAccount.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos guardar la cuenta bancaria.'),
      );
    }
  }

  Future<void> deletePayoutAccount(int id) async {
    try {
      await _dio.delete('/api/business/payout-accounts/$id');
    } on DioException catch (e) {
      throw SellerSettingsException(
        _message(e, 'No pudimos eliminar la cuenta bancaria.'),
      );
    }
  }

  String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    if (e.response?.statusCode == 403) {
      return 'Tu cuenta no tiene permiso para cambiar esta configuración.';
    }
    if ((e.response?.statusCode ?? 0) >= 500) {
      return 'El servicio no está disponible por el momento. Inténtalo más tarde.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'No pudimos conectar con el servidor. Revisa tu internet.';
    }
    return fallback;
  }
}

final sellerSettingsRepositoryProvider = Provider<SellerSettingsRepository>((
  ref,
) {
  return SellerSettingsRepository(ref.read(dioProvider));
});

final sellerBusinessSettingsProvider =
    FutureProvider.autoDispose<SellerBusinessSettings>((ref) {
      return ref.read(sellerSettingsRepositoryProvider).getBusinessSettings();
    });

final sellerPaymentSettingsProvider =
    FutureProvider.autoDispose<MercadoPagoSettings>((ref) {
      return ref.read(sellerSettingsRepositoryProvider).getPaymentSettings();
    });

final sellerPayoutAccountsProvider =
    FutureProvider.autoDispose<List<SellerPayoutAccount>>((ref) {
      return ref.read(sellerSettingsRepositoryProvider).getPayoutAccounts();
    });

class SellerPreferenceSettingsController
    extends Notifier<SellerPreferenceSettings> {
  @override
  SellerPreferenceSettings build() {
    return const SellerPreferenceSettings();
  }

  void set(SellerPreferenceSettings settings) {
    state = settings;
  }
}

final sellerPreferenceSettingsProvider =
    NotifierProvider<
      SellerPreferenceSettingsController,
      SellerPreferenceSettings
    >(SellerPreferenceSettingsController.new);

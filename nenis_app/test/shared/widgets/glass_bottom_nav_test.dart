import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/shared/widgets/glass_bottom_nav.dart';

void main() {
  test('buildDefaultNavItems deja cinco accesos primarios para clientas', () {
    final routes = buildDefaultNavItems().map((item) => item.route);

    expect(routes, hasLength(5));
    expect(routes, contains('/tandas'));
    expect(routes, isNot(contains('/raffles')));
  });

  test('buildDefaultOverflowItems expone Sorteos para clientas', () {
    final routes = buildDefaultOverflowItems().map((item) => item.route);

    expect(routes, contains('/raffles'));
  });

  test('buildSellerNavItems oculta Reparto cuando el rol no tiene acceso', () {
    final routes = buildSellerNavItems(
      includeRoutes: false,
    ).map((item) => item.route);

    expect(routes, hasLength(5));
    expect(routes, isNot(contains('/routes')));
  });

  test('buildSellerOverflowItems mantiene Cuenta y opciones secundarias', () {
    final routes = buildSellerOverflowItems().map((item) => item.route);

    expect(routes, contains('/account'));
    expect(routes, contains('/seller/labels'));
    expect(routes, contains('/seller/inventory'));
  });
}

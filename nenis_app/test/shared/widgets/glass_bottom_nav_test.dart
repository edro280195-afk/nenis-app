import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/shared/widgets/glass_bottom_nav.dart';

void main() {
  test('buildDefaultNavItems expone Tandas y Sorteos para clientas', () {
    final routes = buildDefaultNavItems().map((item) => item.route);

    expect(routes, contains('/tandas'));
    expect(routes, contains('/raffles'));
  });

  test('buildSellerNavItems oculta Reparto cuando el rol no tiene acceso', () {
    final routes = buildSellerNavItems(
      includeRoutes: false,
    ).map((item) => item.route);

    expect(routes, isNot(contains('/routes')));
  });
}

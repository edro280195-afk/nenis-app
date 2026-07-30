import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/live/data/meta_live_probe_models.dart';
import 'package:nenis_app/features/live/data/meta_live_probe_repository.dart';
import 'package:nenis_app/features/live/widgets/meta_live_probe_card.dart';

void main() {
  testWidgets('muestra el resultado de la conexión sin mostrar tokens', (
    tester,
  ) async {
    const result = MetaLiveProbeResult(
      profile: MetaLiveIdentity(id: '100', name: 'Eduardo'),
      grantedPermissions: ['public_profile'],
      declinedPermissions: [],
      missingPermissions: ['publish_video'],
      permissionsError: null,
      pageDiscoveryError: null,
      pagesTruncated: false,
      sources: [
        MetaLiveSource(
          type: 'profile',
          id: '100',
          name: 'Eduardo',
          tasks: [],
          error: null,
          lives: [
            MetaLiveVideo(
              id: '300',
              status: 'LIVE',
              title: 'Venta de prueba',
              description: null,
              permalinkUrl: null,
              createdAt: null,
              commentsError: null,
              comments: [
                MetaLiveComment(
                  id: '400',
                  authorId: '500',
                  authorName: 'Ana',
                  message: 'Mío 12',
                  createdAt: null,
                ),
              ],
            ),
          ],
        ),
      ],
      checkedAt: null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metaLiveProbeRepositoryProvider.overrideWithValue(
            _FakeGateway(result),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MetaLiveProbeCard()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('meta-live-probe-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conectamos con Eduardo'), findsOneWidget);
    expect(find.text('1 Lives'), findsOneWidget);
    expect(find.text('1 comentarios'), findsOneWidget);
    expect(find.textContaining('Ana: Mío 12'), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);
  });
}

class _FakeGateway implements MetaLiveProbeGateway {
  const _FakeGateway(this.result);

  final MetaLiveProbeResult result;

  @override
  Future<MetaLiveProbeResult> probe() async => result;
}

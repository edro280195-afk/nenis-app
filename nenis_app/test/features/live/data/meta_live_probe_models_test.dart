import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/live/data/meta_live_probe_models.dart';

void main() {
  test('interpreta fuentes, Lives, comentarios e identidad del autor', () {
    final result = MetaLiveProbeResult.fromJson({
      'profile': {'id': '100', 'name': 'Eduardo'},
      'grantedPermissions': ['public_profile', 'pages_show_list'],
      'declinedPermissions': ['publish_video'],
      'missingPermissions': ['publish_video'],
      'permissionsError': null,
      'pageDiscoveryError': null,
      'pagesTruncated': false,
      'checkedAtUtc': '2026-07-27T12:00:00Z',
      'sources': [
        {
          'type': 'profile',
          'id': '100',
          'name': 'Eduardo',
          'tasks': <String>[],
          'error': null,
          'lives': [
            {
              'id': '300',
              'status': 'LIVE',
              'title': 'Venta del lunes',
              'description': null,
              'permalinkUrl': '/videos/300',
              'createdAt': '2026-07-27T12:00:00Z',
              'commentsError': null,
              'comments': [
                {
                  'id': '400',
                  'authorId': '500',
                  'authorName': 'Ana',
                  'message': 'Mío 12',
                  'createdAt': '2026-07-27T12:01:00Z',
                },
              ],
            },
          ],
        },
        {
          'type': 'page',
          'id': '200',
          'name': 'Regi Bazar',
          'tasks': ['CREATE_CONTENT'],
          'error': null,
          'lives': <Map<String, Object?>>[],
        },
      ],
    });

    expect(result.profile.name, 'Eduardo');
    expect(result.totalLives, 1);
    expect(result.totalComments, 1);
    expect(result.hasCommentAuthorIds, isTrue);
    expect(result.sources.last.isPage, isTrue);
    expect(result.sources.first.lives.single.comments.single.message, 'Mío 12');
  });
}

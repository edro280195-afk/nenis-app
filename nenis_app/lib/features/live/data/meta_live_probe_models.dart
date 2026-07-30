class MetaLiveProbeResult {
  const MetaLiveProbeResult({
    required this.profile,
    required this.grantedPermissions,
    required this.declinedPermissions,
    required this.missingPermissions,
    required this.permissionsError,
    required this.pageDiscoveryError,
    required this.pagesTruncated,
    required this.sources,
    required this.checkedAt,
  });

  final MetaLiveIdentity profile;
  final List<String> grantedPermissions;
  final List<String> declinedPermissions;
  final List<String> missingPermissions;
  final String? permissionsError;
  final String? pageDiscoveryError;
  final bool pagesTruncated;
  final List<MetaLiveSource> sources;
  final DateTime? checkedAt;

  int get totalLives =>
      sources.fold(0, (total, source) => total + source.lives.length);

  int get totalComments => sources.fold(
    0,
    (total, source) =>
        total +
        source.lives.fold(
          0,
          (liveTotal, live) => liveTotal + live.comments.length,
        ),
  );

  bool get hasCommentAuthorIds => sources.any(
    (source) => source.lives.any(
      (live) =>
          live.comments.any((comment) => comment.authorId?.isNotEmpty == true),
    ),
  );

  factory MetaLiveProbeResult.fromJson(Map<String, dynamic> json) {
    return MetaLiveProbeResult(
      profile: MetaLiveIdentity.fromJson(_jsonMap(json['profile'])),
      grantedPermissions: _stringList(json['grantedPermissions']),
      declinedPermissions: _stringList(json['declinedPermissions']),
      missingPermissions: _stringList(json['missingPermissions']),
      permissionsError: _nullableString(json['permissionsError']),
      pageDiscoveryError: _nullableString(json['pageDiscoveryError']),
      pagesTruncated: json['pagesTruncated'] == true,
      sources: _jsonList(
        json['sources'],
      ).map(MetaLiveSource.fromJson).toList(growable: false),
      checkedAt: DateTime.tryParse(_nullableString(json['checkedAtUtc']) ?? ''),
    );
  }
}

class MetaLiveIdentity {
  const MetaLiveIdentity({required this.id, required this.name});

  final String id;
  final String name;

  factory MetaLiveIdentity.fromJson(Map<String, dynamic> json) {
    return MetaLiveIdentity(
      id: _nullableString(json['id']) ?? '',
      name: _nullableString(json['name']) ?? 'Facebook',
    );
  }
}

class MetaLiveSource {
  const MetaLiveSource({
    required this.type,
    required this.id,
    required this.name,
    required this.tasks,
    required this.error,
    required this.lives,
  });

  final String type;
  final String id;
  final String name;
  final List<String> tasks;
  final String? error;
  final List<MetaLiveVideo> lives;

  bool get isPage => type == 'page';

  factory MetaLiveSource.fromJson(Map<String, dynamic> json) {
    return MetaLiveSource(
      type: _nullableString(json['type']) ?? 'profile',
      id: _nullableString(json['id']) ?? '',
      name: _nullableString(json['name']) ?? 'Facebook',
      tasks: _stringList(json['tasks']),
      error: _nullableString(json['error']),
      lives: _jsonList(
        json['lives'],
      ).map(MetaLiveVideo.fromJson).toList(growable: false),
    );
  }
}

class MetaLiveVideo {
  const MetaLiveVideo({
    required this.id,
    required this.status,
    required this.title,
    required this.description,
    required this.permalinkUrl,
    required this.createdAt,
    required this.commentsError,
    required this.comments,
  });

  final String id;
  final String status;
  final String? title;
  final String? description;
  final String? permalinkUrl;
  final DateTime? createdAt;
  final String? commentsError;
  final List<MetaLiveComment> comments;

  factory MetaLiveVideo.fromJson(Map<String, dynamic> json) {
    return MetaLiveVideo(
      id: _nullableString(json['id']) ?? '',
      status: _nullableString(json['status']) ?? 'UNKNOWN',
      title: _nullableString(json['title']),
      description: _nullableString(json['description']),
      permalinkUrl: _nullableString(json['permalinkUrl']),
      createdAt: DateTime.tryParse(_nullableString(json['createdAt']) ?? ''),
      commentsError: _nullableString(json['commentsError']),
      comments: _jsonList(
        json['comments'],
      ).map(MetaLiveComment.fromJson).toList(growable: false),
    );
  }
}

class MetaLiveComment {
  const MetaLiveComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String? authorId;
  final String? authorName;
  final String message;
  final DateTime? createdAt;

  factory MetaLiveComment.fromJson(Map<String, dynamic> json) {
    return MetaLiveComment(
      id: _nullableString(json['id']) ?? '',
      authorId: _nullableString(json['authorId']),
      authorName: _nullableString(json['authorName']),
      message: _nullableString(json['message']) ?? '',
      createdAt: DateTime.tryParse(_nullableString(json['createdAt']) ?? ''),
    );
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map(_jsonMap).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

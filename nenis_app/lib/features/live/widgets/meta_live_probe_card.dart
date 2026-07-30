import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/meta_live_probe_models.dart';
import '../data/meta_live_probe_repository.dart';

class MetaLiveProbeCard extends ConsumerStatefulWidget {
  const MetaLiveProbeCard({super.key});

  @override
  ConsumerState<MetaLiveProbeCard> createState() => _MetaLiveProbeCardState();
}

class _MetaLiveProbeCardState extends ConsumerState<MetaLiveProbeCard> {
  bool _running = false;
  String? _error;
  MetaLiveProbeResult? _result;

  Future<void> _runProbe() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final result = await ref.read(metaLiveProbeRepositoryProvider).probe();
      if (!mounted) return;
      setState(() => _result = result);
    } on MetaLiveProbeException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos completar la prueba con Facebook.';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        boxShadow: AppShadows.small,
        border: Border.all(color: const Color(0xFFDCE7F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.facebook,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Symbols.link, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Probar conexión con Facebook',
                      style: AppTextStyles.h2.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Revisa si Neni’s puede encontrar tus Lives y leer sus '
                      'comentarios. No publica ni guarda tu acceso.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('meta-live-probe-button'),
              onPressed: _running ? null : _runProbe,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.facebook,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.facebook.withValues(
                  alpha: 0.55,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: _running
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Symbols.fact_check, size: 19),
              label: Text(
                _running ? 'Revisando Facebook…' : 'Autorizar y probar',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            _ProbeNotice(
              icon: Symbols.error,
              color: AppColors.liveRed,
              text: error,
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 14),
            _ProbeResultView(result: result),
          ],
        ],
      ),
    );
  }
}

class _ProbeResultView extends StatelessWidget {
  const _ProbeResultView({required this.result});

  final MetaLiveProbeResult result;

  @override
  Widget build(BuildContext context) {
    final hasBlockingIssue =
        result.permissionsError != null ||
        result.pageDiscoveryError != null ||
        result.missingPermissions.isNotEmpty ||
        result.sources.any((source) => source.error != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProbeNotice(
          icon: hasBlockingIssue ? Symbols.warning : Symbols.check_circle,
          color: hasBlockingIssue
              ? const Color(0xFFB36B00)
              : const Color(0xFF198754),
          text: hasBlockingIssue
              ? 'Conectamos con ${result.profile.name}, pero faltan datos por '
                    'habilitar.'
              : 'Conexión completa con ${result.profile.name}.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricChip(
              icon: Symbols.sensors,
              label: '${result.totalLives} Lives',
            ),
            _MetricChip(
              icon: Symbols.chat_bubble,
              label: '${result.totalComments} comentarios',
            ),
            _MetricChip(
              icon: result.hasCommentAuthorIds
                  ? Symbols.person_check
                  : Symbols.person_off,
              label: result.hasCommentAuthorIds
                  ? 'Autor identificable'
                  : 'Sin ID de autor',
            ),
          ],
        ),
        if (result.missingPermissions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Permisos pendientes',
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            result.missingPermissions.map(_permissionLabel).join(' · '),
            style: AppTextStyles.subtitle.copyWith(fontSize: 11.2),
          ),
        ],
        if (result.permissionsError case final error?) ...[
          const SizedBox(height: 8),
          _InlineError(text: 'Permisos: $error'),
        ],
        if (result.pageDiscoveryError case final error?) ...[
          const SizedBox(height: 8),
          _InlineError(text: 'Páginas: $error'),
        ],
        if (result.pagesTruncated) ...[
          const SizedBox(height: 8),
          Text(
            'Mostramos las primeras 5 Páginas para mantener ligera la prueba.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 10.8),
          ),
        ],
        const SizedBox(height: 12),
        for (final source in result.sources) ...[
          _SourceResult(source: source),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  static String _permissionLabel(String permission) {
    return switch (permission) {
      'publish_video' => 'Lives del perfil',
      'pages_show_list' => 'lista de Páginas',
      'pages_read_engagement' => 'actividad de Página',
      'pages_read_user_content' => 'comentarios de Página',
      'public_profile' => 'perfil público',
      _ => permission,
    };
  }
}

class _SourceResult extends StatelessWidget {
  const _SourceResult({required this.source});

  final MetaLiveSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                source.isPage ? Symbols.flag : Symbols.person,
                size: 18,
                color: AppColors.ink2,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${source.isPage ? 'Página' : 'Perfil'} · ${source.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (source.error case final error?) ...[
            const SizedBox(height: 6),
            _InlineError(text: error),
          ] else if (source.lives.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No encontramos Lives recientes en esta fuente.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 10.8),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final live in source.lives) ...[
              _LiveResult(live: live),
              if (live != source.lives.last) const Divider(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}

class _LiveResult extends StatelessWidget {
  const _LiveResult({required this.live});

  final MetaLiveVideo live;

  @override
  Widget build(BuildContext context) {
    final title = live.title?.trim().isNotEmpty == true
        ? live.title!
        : 'Live sin título';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 11.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              live.status,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: live.status == 'LIVE'
                    ? AppColors.liveRed
                    : AppColors.ink2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${live.comments.length} comentarios legibles',
          style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
        ),
        if (live.commentsError case final error?) ...[
          const SizedBox(height: 4),
          _InlineError(text: error),
        ],
        for (final comment in live.comments.take(2)) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                comment.authorId?.isNotEmpty == true
                    ? Symbols.person_check
                    : Symbols.person,
                size: 15,
                color: AppColors.ink2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${comment.authorName ?? 'Autor no visible'}: '
                  '${comment.message.isEmpty ? '(sin texto)' : comment.message}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 10.4),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF135AB0)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF135AB0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbeNotice extends StatelessWidget {
  const _ProbeNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              fontSize: 11.3,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.subtitle.copyWith(
        fontSize: 10.5,
        color: AppColors.liveRed,
      ),
    );
  }
}

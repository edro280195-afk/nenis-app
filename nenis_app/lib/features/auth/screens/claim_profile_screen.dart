import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../claim/data/claim_models.dart';
import '../../claim/data/claim_repository.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';

const _avatarPalette = [
  [Color(0xFFFF3D8B), Color(0xFFFF0072)],
  [Color(0xFFFF9A6B), Color(0xFFFF7A59)],
  [Color(0xFFA98CF0), Color(0xFF8E6BE6)],
  [Color(0xFF3AD1B8), Color(0xFF16B5A0)],
  [Color(0xFFFFC06F), Color(0xFFF3B341)],
];

class ClaimProfileScreen extends ConsumerStatefulWidget {
  const ClaimProfileScreen({super.key});

  @override
  ConsumerState<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends ConsumerState<ClaimProfileScreen> {
  Set<int>? _selected;
  bool _claiming = false;

  Future<void> _claimAndEnter(List<ClaimCandidate> candidates) async {
    final selected = _selected ?? const {};
    if (selected.isEmpty) {
      context.go('/home');
      return;
    }
    setState(() => _claiming = true);
    final repo = ref.read(claimRepositoryProvider);
    var failures = 0;
    for (final id in selected) {
      try {
        await repo.claimByPhone(id);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    if (failures > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Algunas tiendas no se pudieron reclamar ($failures).')),
      );
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(claimCandidatesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Row(
                  children: [
                    BackIconButton(onPressed: () => context.go('/home')),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Text(
                        'Ahora no',
                        style: AppTextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Te reconocimos 🌸',
                        style: AppTextStyles.eyebrow(AppColors.neniDeep)),
                    const SizedBox(height: 8),
                    Text('Encontramos tu historial\nen estas tiendas',
                        style: AppTextStyles.h1),
                    const SizedBox(height: 9),
                    Text(
                      'Reclámalo para ver tus pedidos pasados y juntar tus puntos. Tú eliges cuáles.',
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: candidatesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.neni),
                  ),
                  error: (err, _) => _ErrorState(
                    onRetry: () => ref.invalidate(claimCandidatesProvider),
                    onEnter: () => context.go('/home'),
                  ),
                  data: (candidates) {
                    if (candidates.isEmpty) {
                      return _EmptyState(onEnter: () => context.go('/home'));
                    }
                    _selected ??= candidates.map((c) => c.clientId).toSet();
                    return _CandidateList(
                      candidates: candidates,
                      selected: _selected!,
                      onToggle: (id) => setState(() {
                        _selected!.contains(id)
                            ? _selected!.remove(id)
                            : _selected!.add(id);
                      }),
                    );
                  },
                ),
              ),
              if (candidatesAsync.asData?.value.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                  child: _claiming
                      ? const _LoadingPill()
                      : PillButton(
                          label: 'Reclamar y entrar',
                          icon: Symbols.arrow_forward,
                          onPressed: () =>
                              _claimAndEnter(candidatesAsync.value!),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.candidates,
    required this.selected,
    required this.onToggle,
  });

  final List<ClaimCandidate> candidates;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
      children: [
        for (final c in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CandidateRow(
              candidate: c,
              isSelected: selected.contains(c.clientId),
              onTap: () => onToggle(c.clientId),
            ),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.statusDeliveredBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.verified_user,
                  color: AppColors.statusDeliveredFg, size: 20, fill: 1),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Solo tú, con tu número ya verificado, puedes reclamar este historial.',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12.5,
                    color: const Color(0xFF137A52),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.isSelected,
    required this.onTap,
  });

  final ClaimCandidate candidate;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _avatarPalette[candidate.businessId % _avatarPalette.length];
    final initial = candidate.businessName.isNotEmpty
        ? candidate.businessName.characters.first.toUpperCase()
        : '?';
    final meta = candidate.city != null && candidate.city!.isNotEmpty
        ? '${candidate.ordersCount} pedidos · ${candidate.city}'
        : '${candidate.ordersCount} pedidos';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.softRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.neni.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.6,
          ),
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadii.avatarRadius,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                initial,
                style: AppTextStyles.h2.copyWith(color: AppColors.surface),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.businessName,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Symbols.shopping_bag,
                          size: 14, color: AppColors.ink2),
                      const SizedBox(width: 5),
                      Text(meta,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.neni : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.neni : AppColors.line,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Symbols.check,
                      color: AppColors.surface, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onEnter});
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: AppColors.surface,
              boxShadow: AppShadows.small,
            ),
            child: const Icon(Symbols.storefront,
                size: 38, color: AppColors.neniDeep),
          ),
          const SizedBox(height: 18),
          Text('Aún no encontramos compras',
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Cuando una tienda registre tu número o abras un pedido desde su link, aparecerá aquí para reclamarlo.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 26),
          PillButton(label: "Entrar a Neni's", onPressed: onEnter),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.onEnter});
  final VoidCallback onRetry;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cloud_off, size: 46, color: AppColors.ink3),
          const SizedBox(height: 14),
          Text('No pudimos cargar tus tiendas',
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Revisa tu conexión e intenta de nuevo.',
              textAlign: TextAlign.center, style: AppTextStyles.subtitle),
          const SizedBox(height: 22),
          PillButton(
              label: 'Reintentar', icon: Symbols.refresh, onPressed: onRetry),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onEnter,
            child: Text('Entrar de todas formas',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.neniDeep,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        gradient: const LinearGradient(
          colors: [AppColors.neni, AppColors.neniDeep],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.surface),
        ),
      ),
    );
  }
}

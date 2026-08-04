import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/subscription/data/subscription_repository.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/interactive_bounce.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';
import '../data/label_print_repository.dart';
import '../services/label_pdf_renderer.dart';
import '../services/label_print_service.dart';
import '../widgets/label_widgets.dart';
import 'label_print_options_sheet.dart';

class LabelBatchPrintScreen extends ConsumerStatefulWidget {
  const LabelBatchPrintScreen({super.key});

  @override
  ConsumerState<LabelBatchPrintScreen> createState() =>
      _LabelBatchPrintScreenState();
}

class _LabelBatchPrintScreenState extends ConsumerState<LabelBatchPrintScreen> {
  final Set<String> _selectedPackageIds = <String>{};
  bool _busy = false;

  bool _hasLabelPlan(String? plan) {
    return plan == 'Pro' || plan == 'Elite';
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  void _showMessage(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? AppColors.ink,
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
        ),
      );
  }

  void _toggle(String id) {
    if (_busy) return;
    setState(() {
      if (!_selectedPackageIds.add(id)) _selectedPackageIds.remove(id);
    });
  }

  void _toggleAll(List<AvailableLabelPackage> packages) {
    if (_busy) return;
    final ids = packages.map((package) => package.id).toSet();
    setState(() {
      if (_selectedPackageIds.containsAll(ids)) {
        _selectedPackageIds.removeAll(ids);
      } else {
        _selectedPackageIds.addAll(ids);
      }
    });
  }

  LabelMediaSize? _sharedMediaSize(List<AvailableLabelPackage> packages) {
    if (packages.isEmpty) return null;
    final first = packages.first.mediaSize;
    for (final package in packages.skip(1)) {
      if (package.mediaSize != first) return null;
    }
    return first;
  }

  Future<void> _printSelected(List<AvailableLabelPackage> available) async {
    if (_selectedPackageIds.isEmpty || _busy) return;
    final selected = available
        .where((package) => _selectedPackageIds.contains(package.id))
        .toList();
    if (selected.isEmpty) return;
    final options = await showLabelPrintOptionsSheet(
      context,
      packageCount: selected.length,
      initialMediaSize: _sharedMediaSize(selected),
    );
    if (options == null || !mounted) return;

    setState(() => _busy = true);
    final repository = ref.read(labelPrintRepositoryProvider);
    LabelPrintJob? job;
    try {
      job = await repository.createJob(
        packageIds: selected.map((package) => package.id).toList(),
        mediaSize: options.mediaSize,
        copies: options.copies,
      );
      final accepted = await const LabelPrintService().handOffToSystem(job);
      await repository.updateJobStatus(
        jobId: job.id,
        status: accepted ? 'SentToSystem' : 'Canceled',
      );
      if (accepted) {
        setState(_selectedPackageIds.clear);
        _showMessage(
          '${job.totalLabels} ${job.totalLabels == 1 ? 'etiqueta enviada' : 'etiquetas enviadas'} al selector de impresión',
          color: AppColors.lavender,
        );
      } else {
        _showMessage('Cancelaste la impresión antes de enviarla.');
      }
    } on LabelPrintException catch (error) {
      if (job != null) await _recordFailure(repository, job.id, error.message);
      if (!mounted) return;
      _showMessage(error.message, color: AppColors.liveRed);
      if (error.isFeatureLocked) context.push('/seller/plan');
    } on LabelPrintRenderException catch (error) {
      if (job != null) await _recordFailure(repository, job.id, error.message);
      _showMessage(error.message, color: AppColors.liveRed);
    } catch (_) {
      if (job != null) {
        await _recordFailure(
          repository,
          job.id,
          'El sistema no pudo abrir la impresión.',
        );
      }
      _showMessage(
        'No pudimos abrir el selector de impresión.',
        color: AppColors.liveRed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordFailure(
    LabelPrintRepository repository,
    String jobId,
    String reason,
  ) async {
    try {
      await repository.updateJobStatus(
        jobId: jobId,
        status: 'Failed',
        failureReason: reason,
      );
    } catch (_) {
      // El error de impresión es el que debe mostrarse; este registro es secundario.
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionStatusProvider);
    final packages = ref.watch(availableLabelPackagesProvider);
    final activePlan = subscription.asData?.value.effectivePlan;
    final unlocked = activePlan == null || _hasLabelPlan(activePlan);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                onBack: _back,
                showInventory: unlocked,
                onInventory: () => context.push('/seller/inventory'),
                onEditTemplate: () =>
                    context.push('/seller/labels/editor?mediaSize=Shipping4x6'),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: !unlocked
                        ? const _LockedLabelsBody()
                        : packages.when(
                            loading: () => const _BatchLoading(),
                            error: (error, _) => _BatchError(
                              onRetry: () => ref.invalidate(
                                availableLabelPackagesProvider,
                              ),
                            ),
                            data: (items) => RefreshIndicator(
                              onRefresh: () async => ref.invalidate(
                                availableLabelPackagesProvider,
                              ),
                              child: _BatchPackageList(
                                packages: items,
                                selectedIds: _selectedPackageIds,
                                busy: _busy,
                                onToggle: _toggle,
                                onToggleAll: () => _toggleAll(items),
                                onEditTemplate: () => context.push(
                                  '/seller/labels/editor?mediaSize=Shipping4x6',
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (unlocked)
                packages.maybeWhen(
                  data: (items) => _BatchFooter(
                    count: _selectedPackageIds.length,
                    busy: _busy,
                    onPrint: () => _printSelected(items),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.showInventory,
    required this.onInventory,
    required this.onEditTemplate,
  });

  final VoidCallback onBack;
  final bool showInventory;
  final VoidCallback onInventory;
  final VoidCallback onEditTemplate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Row(
        children: [
          BackIconButton(onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Etiquetas', style: AppTextStyles.h1.copyWith(fontSize: 22)),
                const SizedBox(height: 1),
                Text(
                  'Bolsa por bolsa, lista para imprimir.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (showInventory) ...[
            PillIconButton(
              onPressed: onInventory,
              icon: Symbols.inventory_2,
              iconColor: AppColors.neniDeep,
              size: 44,
            ),
            const SizedBox(width: 7),
          ],
          PillIconButton(
            onPressed: onEditTemplate,
            icon: Symbols.edit_square,
            iconColor: AppColors.neniDeep,
            size: 44,
          ),
        ],
      ),
    );
  }
}

class _BatchPackageList extends StatelessWidget {
  const _BatchPackageList({
    required this.packages,
    required this.selectedIds,
    required this.busy,
    required this.onToggle,
    required this.onToggleAll,
    required this.onEditTemplate,
  });

  final List<AvailableLabelPackage> packages;
  final Set<String> selectedIds;
  final bool busy;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;
  final VoidCallback onEditTemplate;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) return const _EmptyBatch();
    final groups = _groupByOrder(packages);
    final allSelected = selectedIds.containsAll(
      packages.map((package) => package.id),
    );
    final entries = groups.entries.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 148),
      children: [
        _Hero(
          bagCount: packages.length,
          orderCount: entries.length,
          onEditTemplate: onEditTemplate,
        ),
        const SizedBox(height: 14),
        _SelectAllRow(
          allSelected: allSelected,
          count: selectedIds.length,
          onTap: busy ? null : onToggleAll,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < entries.length; index++) ...[
          _OrderPackageGroup(
            orderId: entries[index].key,
            packages: entries[index].value,
            lavender: index.isOdd,
            selectedIds: selectedIds,
            busy: busy,
            onToggle: onToggle,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Map<int, List<AvailableLabelPackage>> _groupByOrder(
    List<AvailableLabelPackage> packages,
  ) {
    final groups = <int, List<AvailableLabelPackage>>{};
    for (final package in packages) {
      groups.putIfAbsent(package.orderId, () => []).add(package);
    }
    return groups;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.bagCount,
    required this.orderCount,
    required this.onEditTemplate,
  });

  final int bagCount;
  final int orderCount;
  final VoidCallback onEditTemplate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.neni, AppColors.neniDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8CE84E83),
            offset: Offset(0, 18),
            blurRadius: 34,
            spreadRadius: -16,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _DecorativeCircle(size: 150, opacity: 0.14),
          ),
          Positioned(
            right: 34,
            bottom: -44,
            child: _DecorativeCircle(size: 120, opacity: 0.10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para empacar hoy',
                          style: AppTextStyles.eyebrow(
                            Colors.white.withValues(alpha: 0.75),
                          ).copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$bagCount bolsas',
                          style: AppTextStyles.display.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$orderCount ${orderCount == 1 ? 'pedido esperando' : 'pedidos esperando'} su etiqueta',
                          style: AppTextStyles.subtitle.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: LabelQrPlaceholder(size: 40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  const _GhostChip(icon: Symbols.schedule, label: 'Listas hoy'),
                  _GhostChip(
                    icon: Symbols.design_services,
                    label: 'Diseñar etiqueta',
                    onTap: onEditTemplate,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _GhostChip extends StatelessWidget {
  const _GhostChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              fontSize: 10.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InteractiveBounce(
      onPressed: onTap,
      scaleFactor: 0.95,
      child: chip,
    );
  }
}

class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({
    required this.allSelected,
    required this.count,
    required this.onTap,
  });

  final bool allSelected;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      LabelCheck(selected: allSelected, onTap: onTap),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Seleccionar todas',
          style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.neni.withValues(alpha: 0.12),
          borderRadius: AppRadii.pillRadius,
        ),
        child: Text(
          '$count ${count == 1 ? 'seleccionada' : 'seleccionadas'}',
          style: AppTextStyles.chip.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.neniDeep,
          ),
        ),
      ),
    ],
  );
}

class _OrderPackageGroup extends StatelessWidget {
  const _OrderPackageGroup({
    required this.orderId,
    required this.packages,
    required this.lavender,
    required this.selectedIds,
    required this.busy,
    required this.onToggle,
  });

  final int orderId;
  final List<AvailableLabelPackage> packages;
  final bool lavender;
  final Set<String> selectedIds;
  final bool busy;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final client = packages.first.clientName;
    final count = packages.length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                InitialAvatar(name: client, lavender: lavender),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Pedido #$orderId · $count ${count == 1 ? 'bolsa' : 'bolsas'}',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Symbols.expand_more, color: AppColors.ink3, size: 20),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.lineSoft,
          ),
          for (final package in packages)
            _SelectPackageRow(
              item: package,
              selected: selectedIds.contains(package.id),
              busy: busy,
              onTap: () => onToggle(package.id),
            ),
        ],
      ),
    );
  }
}

class _SelectPackageRow extends StatelessWidget {
  const _SelectPackageRow({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final AvailableLabelPackage item;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loaded = item.status == 'Loaded';
    final (String pillLabel, LabelStatusPillVariant pillVariant) = selected
        ? ('Seleccionada', LabelStatusPillVariant.selected)
        : loaded
        ? ('En ruta', LabelStatusPillVariant.route)
        : ('Lista', LabelStatusPillVariant.ready);
    final ship = item.mediaSize == LabelMediaSize.shipping4x6;
    final subtitle = ship
        ? 'Envío 4 × 6" · dirección y contenido'
        : '50 × 50 mm · QR propio';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              MiniLabelPreview(
                code: 'B-${item.packageNumber}',
                format: ship
                    ? MiniLabelFormat.shipping4x6
                    : MiniLabelFormat.square50,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bolsa ${item.packageNumber} de ${item.totalPackages}',
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LabelStatusPill(label: pillLabel, variant: pillVariant),
              const SizedBox(width: 6),
              LabelCheck(selected: selected, onTap: busy ? null : onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchFooter extends StatelessWidget {
  const _BatchFooter({
    required this.count,
    required this.busy,
    required this.onPrint,
  });

  final int count;
  final bool busy;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'bolsa seleccionada' : 'bolsas seleccionadas'}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Puedes mezclar formatos al elegir tu impresora',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PillButton(
                  label: count == 0
                      ? 'Selecciona bolsas para imprimir'
                      : busy
                      ? 'Abriendo impresoras...'
                      : 'Imprimir $count ${count == 1 ? 'etiqueta' : 'etiquetas'}',
                  icon: Symbols.print,
                  onPressed: count == 0 || busy ? null : onPrint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedLabelsBody extends StatelessWidget {
  const _LockedLabelsBody();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(18),
    child: Center(child: LabelFeatureLockedView()),
  );
}

class _BatchLoading extends StatelessWidget {
  const _BatchLoading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 148),
    children: [
      Container(
        height: 148,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBD3E0), Color(0xFFF7B7CB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < 2; index++) ...[
        Container(
          height: 148,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
            boxShadow: AppShadows.small,
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class _BatchError extends StatelessWidget {
  const _BatchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.cloud_off, size: 44, color: AppColors.ink3),
          const SizedBox(height: 12),
          Text(
            'No pudimos cargar las bolsas.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          PillButton(
            label: 'Reintentar',
            expand: false,
            icon: Symbols.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}

class _EmptyBatch extends StatelessWidget {
  const _EmptyBatch();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.inventory_2,
              size: 30,
              color: AppColors.neniDeep,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'No hay bolsas pendientes',
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 5),
          Text(
            'Crea las bolsas desde el detalle de un pedido cuando empieces a empacar.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Ver mis pedidos',
            expand: false,
            icon: Symbols.shopping_bag,
            onPressed: () => context.go('/orders'),
          ),
        ],
      ),
    ),
  );
}

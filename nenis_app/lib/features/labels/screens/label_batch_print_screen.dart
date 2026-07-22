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
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';
import '../data/label_print_repository.dart';
import '../services/label_pdf_renderer.dart';
import '../services/label_print_service.dart';
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

  Future<void> _printSelected(List<AvailableLabelPackage> available) async {
    if (_selectedPackageIds.isEmpty || _busy) return;
    final selected = available
        .where((package) => _selectedPackageIds.contains(package.id))
        .toList();
    if (selected.isEmpty) return;
    final options = await showLabelPrintOptionsSheet(
      context,
      packageCount: selected.length,
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
                child: !unlocked
                    ? const _LockedLabelsBody()
                    : packages.when(
                        loading: () => const _BatchLoading(),
                        error: (error, _) => _BatchError(
                          onRetry: () =>
                              ref.invalidate(availableLabelPackagesProvider),
                        ),
                        data: (items) => RefreshIndicator(
                          onRefresh: () async =>
                              ref.invalidate(availableLabelPackagesProvider),
                          child: _BatchPackageList(
                            packages: items,
                            selectedIds: _selectedPackageIds,
                            busy: _busy,
                            onToggle: _toggle,
                            onToggleAll: () => _toggleAll(items),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        children: [
          BackIconButton(onPressed: onBack),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imprimir etiquetas',
                  style: AppTextStyles.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 1),
                Text(
                  'Selecciona bolsas y elige tu impresora al final.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (showInventory)
            IconButton(
              onPressed: onInventory,
              tooltip: 'Abrir mi bodega',
              icon: const Icon(Symbols.inventory_2, color: AppColors.neniDeep),
            ),
          IconButton(
            onPressed: onEditTemplate,
            tooltip: 'Diseñar etiqueta',
            icon: const Icon(Symbols.edit_square, color: AppColors.neniDeep),
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
  });

  final List<AvailableLabelPackage> packages;
  final Set<String> selectedIds;
  final bool busy;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) return const _EmptyBatch();
    final groups = _groupByOrder(packages);
    final allSelected = selectedIds.containsAll(
      packages.map((package) => package.id),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 148),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.lineSoft),
            borderRadius: AppRadii.softRadius,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.qr_code_2,
                  color: AppColors.lavender,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${packages.length} bolsas listas para identificar',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onToggleAll,
                child: Text(allSelected ? 'Limpiar' : 'Todas'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final entry in groups.entries) ...[
          _OrderPackageGroup(
            orderId: entry.key,
            packages: entry.value,
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

class _OrderPackageGroup extends StatelessWidget {
  const _OrderPackageGroup({
    required this.orderId,
    required this.packages,
    required this.selectedIds,
    required this.busy,
    required this.onToggle,
  });

  final int orderId;
  final List<AvailableLabelPackage> packages;
  final Set<String> selectedIds;
  final bool busy;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final client = packages.first.clientName;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pedido #$orderId · ${packages.length} ${packages.length == 1 ? 'bolsa' : 'bolsas'}',
                        style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Symbols.shopping_bag,
                  color: AppColors.neniDeep,
                  size: 21,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lineSoft),
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
    final subtitle = item.status == 'Loaded'
        ? 'En ruta · se permite reimpresión'
        : 'Lista para empacar';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: busy ? null : (_) => onTap(),
                activeColor: AppColors.neniDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  'Bolsa ${item.packageNumber} de ${item.totalPackages}',
                  style: AppTextStyles.body.copyWith(fontSize: 13.5),
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
              ),
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
        child: PillButton(
          label: count == 0
              ? 'Selecciona bolsas para imprimir'
              : busy
              ? 'Abriendo impresoras...'
              : 'Imprimir $count ${count == 1 ? 'etiqueta' : 'etiquetas'}',
          icon: Symbols.print,
          onPressed: count == 0 || busy ? null : onPrint,
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
    padding: const EdgeInsets.all(18),
    children: [
      for (var index = 0; index < 3; index++) ...[
        Container(
          height: 132,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardRadius,
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
        ],
      ),
    ),
  );
}

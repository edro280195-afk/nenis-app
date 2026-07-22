import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/subscription/data/subscription_repository.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/label_print_models.dart';
import '../data/label_print_repository.dart';
import '../services/label_pdf_renderer.dart';
import '../services/label_print_service.dart';
import 'label_print_options_sheet.dart';

class OrderLabelSection extends ConsumerStatefulWidget {
  const OrderLabelSection({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderLabelSection> createState() => _OrderLabelSectionState();
}

class _OrderLabelSectionState extends ConsumerState<OrderLabelSection> {
  bool _busy = false;

  bool _hasLabelPlan(String? plan) {
    return plan == 'Pro' || plan == 'Elite';
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

  Future<void> _generatePackages() async {
    final count = await _askPackageCount();
    if (count == null || count < 1) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(labelPrintRepositoryProvider)
          .generateOrderPackages(orderId: widget.orderId, count: count);
      ref.invalidate(orderLabelPackagesProvider(widget.orderId));
      ref.invalidate(availableLabelPackagesProvider);
      _showMessage(
        '${count == 1 ? 'Bolsa creada' : '$count bolsas creadas'} · ya puedes imprimir sus etiquetas',
        color: AppColors.lavender,
      );
    } on LabelPrintException catch (error) {
      _showMessage(error.message, color: AppColors.liveRed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPackages(List<OrderPackageLabel> packages) async {
    if (packages.isEmpty || _busy) return;
    final options = await showLabelPrintOptionsSheet(
      context,
      packageCount: packages.length,
    );
    if (options == null || !mounted) return;

    setState(() => _busy = true);
    final repository = ref.read(labelPrintRepositoryProvider);
    LabelPrintJob? job;
    try {
      job = await repository.createJob(
        packageIds: packages.map((package) => package.id).toList(),
        mediaSize: options.mediaSize,
        copies: options.copies,
      );
      final accepted = await const LabelPrintService().handOffToSystem(job);
      await repository.updateJobStatus(
        jobId: job.id,
        status: accepted ? 'SentToSystem' : 'Canceled',
      );
      if (accepted) {
        _showMessage(
          '${job.totalLabels} ${job.totalLabels == 1 ? 'etiqueta enviada' : 'etiquetas enviadas'} al selector de impresión',
          color: AppColors.lavender,
        );
      } else {
        _showMessage('No se envió ninguna etiqueta a imprimir.');
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
      // La falla primaria sigue siendo la relevante para la vendedora.
    }
  }

  Future<int?> _askPackageCount() async {
    final controller = TextEditingController(text: '1');
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: AppRadii.pillRadius,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Cuántas bolsas lleva?',
                  style: AppTextStyles.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  'Crearemos bolsas reales; cada una tendrá su propio QR.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: '1',
                    border: OutlineInputBorder(
                      borderRadius: AppRadii.fieldRadius,
                      borderSide: const BorderSide(color: AppColors.lineSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PillButton(
                  label: 'Crear bolsas',
                  icon: Symbols.inventory_2,
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());
                    if (value != null && value > 0 && value <= 100) {
                      Navigator.of(sheetContext).pop(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionStatusProvider);
    final packages = ref.watch(orderLabelPackagesProvider(widget.orderId));
    final activePlan = subscription.asData?.value.effectivePlan;
    final unlocked = activePlan == null || _hasLabelPlan(activePlan);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.print, size: 19, color: AppColors.neniDeep),
              const SizedBox(width: 8),
              Text(
                'Bolsas y etiquetas',
                style: AppTextStyles.h2.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!unlocked)
            const LabelFeatureLockedView(compact: true)
          else
            packages.when(
              loading: () => const _PackagesLoading(),
              error: (error, _) => _PackagesError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(orderLabelPackagesProvider(widget.orderId)),
              ),
              data: (items) => _PackagesContent(
                packages: items,
                busy: _busy,
                onGenerate: _generatePackages,
                onPrint: () => _printPackages(items),
                onPrintOne: (item) => _printPackages([item]),
                onOpenBatch: () => context.push('/seller/labels'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PackagesContent extends StatelessWidget {
  const _PackagesContent({
    required this.packages,
    required this.busy,
    required this.onGenerate,
    required this.onPrint,
    required this.onPrintOne,
    required this.onOpenBatch,
  });

  final List<OrderPackageLabel> packages;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onPrint;
  final ValueChanged<OrderPackageLabel> onPrintOne;
  final VoidCallback onOpenBatch;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardRadius,
          boxShadow: AppShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este pedido todavía no tiene bolsas.',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Créelas cuando empieces a empacar; no son etiquetas de prueba.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            PillButton(
              label: busy ? 'Creando bolsas...' : 'Generar bolsas',
              icon: Symbols.inventory_2,
              onPressed: busy ? null : onGenerate,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${packages.length} ${packages.length == 1 ? 'bolsa lista' : 'bolsas listas'}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onGenerate,
                  icon: const Icon(Symbols.add, size: 17),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neniDeep,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lineSoft),
          for (final item in packages)
            _PackageRow(
              item: item,
              busy: busy,
              onPrint: () => onPrintOne(item),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: PillButton(
              label: busy
                  ? 'Abriendo impresoras...'
                  : 'Imprimir ${packages.length} etiquetas',
              icon: Symbols.print,
              onPressed: busy ? null : onPrint,
            ),
          ),
          TextButton(
            onPressed: busy ? null : onOpenBatch,
            child: const Text('Abrir centro de impresión masiva'),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.item,
    required this.busy,
    required this.onPrint,
  });

  final OrderPackageLabel item;
  final bool busy;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final status = item.status == 'Loaded' ? 'En ruta' : 'Empacada';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${item.packageNumber}',
              style: AppTextStyles.h2.copyWith(
                fontSize: 14,
                color: AppColors.neniDeep,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bolsa ${item.packageNumber}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onPrint,
            tooltip: 'Imprimir esta etiqueta',
            color: AppColors.neniDeep,
            icon: const Icon(Symbols.print, size: 21),
          ),
        ],
      ),
    );
  }
}

class _PackagesLoading extends StatelessWidget {
  const _PackagesLoading();

  @override
  Widget build(BuildContext context) => Container(
    height: 128,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.cardRadius,
    ),
  );
}

class _PackagesError extends StatelessWidget {
  const _PackagesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.cardRadius,
    ),
    child: Row(
      children: [
        const Icon(Symbols.cloud_off, color: AppColors.ink3),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No pudimos ver las bolsas.',
            style: AppTextStyles.subtitle,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

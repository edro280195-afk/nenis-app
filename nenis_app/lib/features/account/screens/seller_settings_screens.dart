import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_hex.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';
import '../data/seller_settings_models.dart';
import '../data/seller_settings_repository.dart';

const _configSections = [
  _ConfigSectionInfo(
    title: 'Perfil de tienda',
    subtitle: 'Nombre, colores y vista pública.',
    route: '/seller/settings/profile',
    icon: Symbols.storefront,
    color: AppColors.neniDeep,
  ),
  _ConfigSectionInfo(
    title: 'Métodos de pago',
    subtitle: 'Mercado Pago y cobros para tus clientas.',
    route: '/seller/settings/payments',
    icon: Symbols.payments,
    color: AppColors.statusRouteFg,
  ),
  _ConfigSectionInfo(
    title: 'Equipo de reparto',
    subtitle: 'Cómo trabajan tus choferes con las rutas.',
    route: '/seller/settings/team',
    icon: Symbols.groups,
    color: AppColors.statusDeliveredFg,
  ),
  _ConfigSectionInfo(
    title: 'Preferencias',
    subtitle: 'Alertas, mensajes y operación diaria.',
    route: '/seller/settings/preferences',
    icon: Symbols.tune,
    color: AppColors.lavender,
  ),
];

class SellerSettingsScreen extends ConsumerWidget {
  const SellerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerBusinessSettingsProvider);
    return _SettingsScaffold(
      title: 'Configuración',
      subtitle: 'Ajusta tu tienda sin perder el ritmo de venta.',
      child: async.when(
        loading: () => const _SettingsLoading(),
        error: (error, _) => _SettingsError(
          message: error.toString(),
          onRetry: () => ref.invalidate(sellerBusinessSettingsProvider),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _BusinessSummaryCard(settings: settings),
            const SizedBox(height: 18),
            Text(
              'Centro de control',
              style: AppTextStyles.eyebrow(AppColors.neniDeep),
            ),
            const SizedBox(height: 10),
            ..._configSections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SettingsNavigationTile(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerStoreProfileSettingsScreen extends ConsumerStatefulWidget {
  const SellerStoreProfileSettingsScreen({super.key});

  @override
  ConsumerState<SellerStoreProfileSettingsScreen> createState() =>
      _SellerStoreProfileSettingsScreenState();
}

class _SellerStoreProfileSettingsScreenState
    extends ConsumerState<SellerStoreProfileSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _primaryCtrl = TextEditingController();
  final _accentCtrl = TextEditingController();
  var _hydrated = false;
  var _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _primaryCtrl.dispose();
    _accentCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final name = _nameCtrl.text.trim();
    final primary = _primaryCtrl.text.trim();
    final accent = _accentCtrl.text.trim();
    return name.isNotEmpty &&
        name.length <= 150 &&
        _isHexColor(primary) &&
        (accent.isEmpty || _isHexColor(accent));
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .updateBrand(
            name: _nameCtrl.text,
            primaryColor: _primaryCtrl.text,
            accentColor: _accentCtrl.text,
          );
      ref.invalidate(sellerBusinessSettingsProvider);
      if (!mounted) return;
      _snack(context, 'Perfil de tienda guardado.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerBusinessSettingsProvider);
    return _SettingsScaffold(
      title: 'Perfil de tienda',
      subtitle: 'Lo que ven tus clientas cuando entran a comprar.',
      bottomBar: _SaveBar(
        saving: _saving,
        enabled: _isValid,
        label: 'Guardar perfil',
        onPressed: _save,
      ),
      child: async.when(
        loading: () => const _SettingsLoading(),
        error: (error, _) => _SettingsError(
          message: error.toString(),
          onRetry: () => ref.invalidate(sellerBusinessSettingsProvider),
        ),
        data: (settings) {
          if (!_hydrated) {
            _nameCtrl.text = settings.name;
            _primaryCtrl.text = settings.brand.primaryColor;
            _accentCtrl.text = settings.brand.accentColor ?? '';
            _hydrated = true;
          }

          final primary = colorFromHex(_primaryCtrl.text);
          final accent = _accentCtrl.text.trim().isEmpty
              ? lighten(primary, 0.15)
              : colorFromHex(_accentCtrl.text);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _StorePreviewCard(
                name: _nameCtrl.text.trim().isEmpty
                    ? 'Mi tienda'
                    : _nameCtrl.text.trim(),
                slug: settings.slug,
                city: settings.city,
                primary: primary,
                accent: accent,
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                title: 'Identidad',
                subtitle: 'Usa un nombre corto y reconocible.',
                children: [
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Nombre público',
                    hint: 'Regi Bazar',
                    prefixIcon: Symbols.storefront,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _ReadOnlyInfoRow(
                    icon: Symbols.link,
                    title: 'Ruta pública',
                    value: '/${settings.slug}',
                  ),
                  if (settings.city?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    _ReadOnlyInfoRow(
                      icon: Symbols.location_on,
                      title: 'Ciudad',
                      value: settings.city!,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                title: 'Colores de marca',
                subtitle: 'Formato requerido: #RRGGBB.',
                children: [
                  _ColorTextField(
                    controller: _primaryCtrl,
                    label: 'Color principal',
                    fallback: AppColors.neniDeep,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _ColorTextField(
                    controller: _accentCtrl,
                    label: 'Color de acento',
                    hint: 'Opcional',
                    fallback: AppColors.gold,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ColorPreset(
                        label: 'Neni',
                        value: '#FB6F9C',
                        onTap: () {
                          _primaryCtrl.text = '#FB6F9C';
                          setState(() {});
                        },
                      ),
                      _ColorPreset(
                        label: 'Regi',
                        value: '#FF0072',
                        onTap: () {
                          _primaryCtrl.text = '#FF0072';
                          setState(() {});
                        },
                      ),
                      _ColorPreset(
                        label: 'Lila',
                        value: '#9B7BE0',
                        onTap: () {
                          _primaryCtrl.text = '#9B7BE0';
                          setState(() {});
                        },
                      ),
                      _ColorPreset(
                        label: 'Dorado',
                        value: '#F3B341',
                        onTap: () {
                          _primaryCtrl.text = '#F3B341';
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isValid) ...[
                const SizedBox(height: 12),
                const _InlineWarning(
                  text:
                      'Revisa que el nombre no esté vacío y que los colores usen formato #RRGGBB.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// SellerPaymentSettingsScreen movido a payment_methods_screen.dart

class SellerTeamSettingsScreen extends StatefulWidget {
  const SellerTeamSettingsScreen({super.key});

  @override
  State<SellerTeamSettingsScreen> createState() =>
      _SellerTeamSettingsScreenState();
}

class _SellerTeamSettingsScreenState extends State<SellerTeamSettingsScreen> {
  var _driverCanCollect = true;
  var _driverCanChat = true;
  var _requireEvidence = true;
  var _saving = false;

  Future<void> _copyInviteMessage() async {
    const text =
        'Hola, te voy a compartir tu enlace de ruta desde Neni. '
        'Ábrelo en tu celular, permite ubicación y mantén la app abierta '
        'mientras repartes para que las clientas vean el avance.';
    await Clipboard.setData(const ClipboardData(text: text));
    if (!mounted) return;
    _snack(context, 'Mensaje para chofer copiado.');
    HapticFeedback.selectionClick();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(context, 'Preferencias de reparto guardadas en esta sesión.');
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Equipo de reparto',
      subtitle: 'Prepara a tus choferes para rutas más claras.',
      bottomBar: _SaveBar(
        saving: _saving,
        enabled: true,
        label: 'Guardar reparto',
        onPressed: _save,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _RouteFlowCard(),
          const SizedBox(height: 18),
          _SettingsCard(
            title: 'Permisos del chofer',
            subtitle: 'Estos ajustes guían cómo operas cada ruta.',
            children: [
              _SwitchRow(
                title: 'Puede registrar cobros',
                subtitle: 'Útil cuando cobra contra entrega.',
                value: _driverCanCollect,
                onChanged: (value) => setState(() => _driverCanCollect = value),
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                title: 'Puede escribir a clientas',
                subtitle: 'Activa chat operativo durante el reparto.',
                value: _driverCanChat,
                onChanged: (value) => setState(() => _driverCanChat = value),
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                title: 'Pedir evidencia al entregar',
                subtitle: 'Foto o nota cuando marca entregado.',
                value: _requireEvidence,
                onChanged: (value) => setState(() => _requireEvidence = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'Mensaje para compartir',
            subtitle: 'Úsalo cuando le mandes su enlace de ruta.',
            children: [
              Text(
                '“Abre tu ruta, permite ubicación y marca cada entrega al terminar.”',
                style: AppTextStyles.body.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              PillButton(
                label: 'Copiar mensaje',
                icon: Symbols.content_copy,
                expand: false,
                variant: PillButtonVariant.brand,
                onPressed: _copyInviteMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SellerPreferencesSettingsScreen extends ConsumerStatefulWidget {
  const SellerPreferencesSettingsScreen({super.key});

  @override
  ConsumerState<SellerPreferencesSettingsScreen> createState() =>
      _SellerPreferencesSettingsScreenState();
}

class _SellerPreferencesSettingsScreenState
    extends ConsumerState<SellerPreferencesSettingsScreen> {
  late SellerPreferenceSettings _draft;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(sellerPreferenceSettingsProvider);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    ref.read(sellerPreferenceSettingsProvider.notifier).set(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(context, 'Preferencias guardadas.');
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Preferencias',
      subtitle: 'Pequeños ajustes para vender más fluido.',
      bottomBar: _SaveBar(
        saving: _saving,
        enabled: true,
        label: 'Guardar preferencias',
        onPressed: _save,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _SettingsCard(
            title: 'Alertas',
            subtitle: 'Mantente enterada sin llenar la pantalla de ruido.',
            children: [
              _SwitchRow(
                title: 'Pedidos nuevos',
                subtitle: 'Avisar cuando entra una orden.',
                value: _draft.notifyNewOrders,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(notifyNewOrders: value),
                ),
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                title: 'Cambios en rutas',
                subtitle: 'Avisar si una entrega cambia de estado.',
                value: _draft.notifyRouteChanges,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(notifyRouteChanges: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            title: 'Operación',
            subtitle: 'Define el comportamiento base al capturar pedidos.',
            children: [
              _SwitchRow(
                title: 'Copiar mensaje al crear pedido',
                subtitle: 'Deja listo el texto para mandarlo a la clienta.',
                value: _draft.autoCopyClientMessage,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(autoCopyClientMessage: value),
                ),
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                title: 'Pedir anticipo antes de ruta',
                subtitle: 'Marca como recomendado cobrar antes de repartir.',
                value: _draft.requirePaymentBeforeRoute,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(
                    requirePaymentBeforeRoute: value,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _DeliveryWindowSelector(
                value: _draft.defaultDeliveryWindow,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(defaultDeliveryWindow: value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomBar,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      bottomNavigationBar: bottomBar,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
                child: Row(
                  children: [
                    BackIconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/account'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.h1.copyWith(fontSize: 24),
                          ),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 12.5,
                              color: AppColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessSummaryCard extends StatelessWidget {
  const _BusinessSummaryCard({required this.settings});
  final SellerBusinessSettings settings;

  @override
  Widget build(BuildContext context) {
    final primary = colorFromHex(settings.brand.primaryColor);
    final accent = settings.brand.accentColor == null
        ? lighten(primary, 0.16)
        : colorFromHex(settings.brand.accentColor);
    final initial = settings.name.trim().isEmpty
        ? 'N'
        : settings.name.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lighten(primary, 0.34), lighten(accent, 0.22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoBubble(label: initial, primary: primary, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(fontSize: 18),
                    ),
                    Text(
                      settings.city?.trim().isNotEmpty == true
                          ? '${settings.city} · /${settings.slug}'
                          : '/${settings.slug}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                icon: Symbols.workspace_premium,
                label: 'Plan ${settings.subscription.effectivePlan}',
                color: primary,
              ),
              _MiniPill(
                icon: settings.subscription.isLocked
                    ? Symbols.lock
                    : Symbols.verified,
                label: settings.subscription.isLocked ? 'Bloqueado' : 'Activo',
                color: settings.subscription.isLocked
                    ? AppColors.liveRed
                    : AppColors.statusDeliveredFg,
              ),
              _MiniPill(
                icon: Symbols.extension,
                label: '${settings.features.length} funciones',
                color: AppColors.lavender,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({required this.section});
  final _ConfigSectionInfo section;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(section.route),
        borderRadius: AppRadii.softRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              _IconBadge(icon: section.icon, color: section.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                size: 22,
                color: AppColors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorePreviewCard extends StatelessWidget {
  const _StorePreviewCard({
    required this.name,
    required this.slug,
    required this.primary,
    required this.accent,
    this.city,
  });

  final String name;
  final String slug;
  final String? city;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().substring(0, 1).toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lighten(primary, 0.28), lighten(accent, 0.24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardRadius,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LogoBubble(label: initial, primary: primary, accent: accent),
              const Spacer(),
              _MiniPill(
                icon: Symbols.visibility,
                label: 'Vista pública',
                color: primary,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h1.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            city?.trim().isNotEmpty == true
                ? '$city · nenis.app/$slug'
                : 'nenis.app/$slug',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 12.5,
              color: AppColors.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteFlowCard extends StatelessWidget {
  const _RouteFlowCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Symbols.route,
                color: AppColors.statusDeliveredFg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Flujo recomendado',
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _StepLine(
            number: '1',
            title: 'Arma la ruta',
            subtitle: 'Selecciona pedidos y tandas desde Reparto.',
          ),
          const _StepLine(
            number: '2',
            title: 'Comparte el enlace',
            subtitle: 'El chofer abre su ruta desde el celular.',
          ),
          const _StepLine(
            number: '3',
            title: 'Monitorea entregas',
            subtitle: 'Los estados y ubicación se actualizan en vivo.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.saving,
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: PillButton(
          key: ValueKey('$saving-$enabled-$label'),
          label: saving ? 'Guardando...' : label,
          icon: saving ? Symbols.hourglass_top : Symbols.save,
          variant: PillButtonVariant.brand,
          onPressed: enabled && !saving ? onPressed : null,
        ),
      ),
    );
  }
}

class _ColorTextField extends StatelessWidget {
  const _ColorTextField({
    required this.controller,
    required this.label,
    required this.fallback,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final Color fallback;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final raw = controller.text.trim();
    final valid = raw.isEmpty ? hint != null : _isHexColor(raw);
    final color = valid && raw.isNotEmpty ? colorFromHex(raw) : fallback;
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint ?? '#FB6F9C',
      prefixIcon: Symbols.palette,
      textInputAction: TextInputAction.next,
      onChanged: (_) => onChanged(),
      suffix: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: valid ? Colors.white : AppColors.liveRed,
            width: 2,
          ),
          boxShadow: AppShadows.small,
        ),
      ),
    );
  }
}

class _ColorPreset extends StatelessWidget {
  const _ColorPreset({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: lighten(color, 0.36),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                '$label $value',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 11.5,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeThumbColor: AppColors.neniDeep,
              activeTrackColor: AppColors.neni.withValues(alpha: 0.36),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryWindowSelector extends StatelessWidget {
  const _DeliveryWindowSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    'Domingos por la tarde',
    'Entre semana',
    'Mismo día',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ventana de entrega predeterminada',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.map((option) {
            final selected = option == value;
            return ChoiceChip(
              label: Text(option),
              selected: selected,
              showCheckmark: false,
              selectedColor: const Color(0xFFFFDDE9),
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: selected ? AppColors.neniDeep : AppColors.line,
              ),
              labelStyle: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: selected ? AppColors.neniDeep : AppColors.ink2,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  const _ReadOnlyInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusPendingBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.statusPendingFg.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Symbols.info, size: 20, color: AppColors.statusPendingFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                color: AppColors.statusPendingFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.number,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.statusDeliveredBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: AppColors.statusDeliveredFg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: AppColors.statusDeliveredBg,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoBubble extends StatelessWidget {
  const _LogoBubble({
    required this.label,
    required this.primary,
    required this.accent,
  });

  final String label;
  final Color primary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, accent]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.brandSmall(primary),
      ),
      child: Text(
        label,
        style: AppTextStyles.h1.copyWith(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 11.5,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      children: [
        const Icon(Symbols.cloud_off, color: AppColors.ink3, size: 46),
        const SizedBox(height: 12),
        Text(
          'No pudimos abrir configuración',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 18),
        PillButton(
          label: 'Reintentar',
          icon: Symbols.refresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ConfigSectionInfo {
  const _ConfigSectionInfo({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;
}

bool _isHexColor(String value) {
  return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value.trim());
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.liveRed : AppColors.ink,
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      ),
    );
}

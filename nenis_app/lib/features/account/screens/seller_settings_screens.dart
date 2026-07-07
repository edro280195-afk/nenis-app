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

class SellerPaymentSettingsScreen extends ConsumerStatefulWidget {
  const SellerPaymentSettingsScreen({super.key});

  @override
  ConsumerState<SellerPaymentSettingsScreen> createState() =>
      _SellerPaymentSettingsScreenState();
}

class _SellerPaymentSettingsScreenState
    extends ConsumerState<SellerPaymentSettingsScreen> {
  final _publicKeyCtrl = TextEditingController();
  final _accessTokenCtrl = TextEditingController();
  var _hydrated = false;
  var _clearToken = false;
  var _saving = false;

  @override
  void dispose() {
    _publicKeyCtrl.dispose();
    _accessTokenCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    final publicKey = _publicKeyCtrl.text.trim();
    final accessToken = _accessTokenCtrl.text.trim();
    return !_hasSpaces(publicKey) &&
        !_hasSpaces(accessToken) &&
        publicKey.length <= 200 &&
        accessToken.length <= 500;
  }

  Future<void> _saveMercadoPago() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .updatePaymentSettings(
            publicKey: _publicKeyCtrl.text,
            accessToken: _accessTokenCtrl.text.trim().isEmpty
                ? null
                : _accessTokenCtrl.text,
            clearAccessToken: _clearToken,
          );
      ref.invalidate(sellerPaymentSettingsProvider);
      _accessTokenCtrl.clear();
      if (!mounted) return;
      setState(() => _clearToken = false);
      _snack(context, 'Métodos de pago guardados.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPayoutSheet([SellerPayoutAccount? account]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PayoutAccountSheet(account: account),
    );

    if (changed == true) {
      ref.invalidate(sellerPayoutAccountsProvider);
    }
  }

  Future<void> _setDefaultPayoutAccount(SellerPayoutAccount account) async {
    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .updatePayoutAccount(id: account.id, isDefault: true);
      ref.invalidate(sellerPayoutAccountsProvider);
      if (!mounted) return;
      _snack(context, 'Cuenta predeterminada actualizada.');
      HapticFeedback.selectionClick();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    }
  }

  Future<void> _deletePayoutAccount(SellerPayoutAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text(
          'Se quitará ${account.displayName} de tus opciones de transferencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .deletePayoutAccount(account.id);
      ref.invalidate(sellerPayoutAccountsProvider);
      if (!mounted) return;
      _snack(context, 'Cuenta eliminada.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sellerPaymentSettingsProvider);
    final payoutAccounts = ref.watch(sellerPayoutAccountsProvider);
    return _SettingsScaffold(
      title: 'Métodos de pago',
      subtitle: 'Cuentas para transferencias y cobros con link.',
      bottomBar: _SaveBar(
        saving: _saving,
        enabled: _isValid,
        label: 'Guardar Mercado Pago',
        onPressed: _saveMercadoPago,
      ),
      child: async.when(
        loading: () => const _SettingsLoading(),
        error: (error, _) => _SettingsError(
          message: error.toString(),
          onRetry: () => ref.invalidate(sellerPaymentSettingsProvider),
        ),
        data: (settings) {
          if (!_hydrated) {
            _publicKeyCtrl.text = settings.publicKey ?? '';
            _hydrated = true;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 126),
            children: [
              _PayoutIntroCard(onAdd: () => _openPayoutSheet()),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: payoutAccounts.when(
                  loading: () => const _PayoutAccountsLoading(),
                  error: (error, _) => _PayoutAccountsError(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(sellerPayoutAccountsProvider),
                  ),
                  data: (accounts) => _PayoutAccountsSection(
                    accounts: accounts,
                    onAdd: () => _openPayoutSheet(),
                    onEdit: _openPayoutSheet,
                    onMakeDefault: _setDefaultPayoutAccount,
                    onDelete: _deletePayoutAccount,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PaymentStatusCard(settings: settings),
              const SizedBox(height: 18),
              _SettingsCard(
                title: 'Mercado Pago link',
                subtitle:
                    'Opcional para cobros con tarjeta o link. El Access Token nunca se muestra después de guardarlo.',
                children: [
                  AppTextField(
                    controller: _publicKeyCtrl,
                    label: 'Public Key',
                    hint: 'APP_USR-...',
                    prefixIcon: Symbols.key,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _accessTokenCtrl,
                    label: settings.hasAccessToken
                        ? 'Nuevo Access Token'
                        : 'Access Token',
                    hint: settings.hasAccessToken
                        ? 'Déjalo vacío para conservar el actual'
                        : 'APP_USR-...',
                    prefixIcon: Symbols.lock,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    enableSuggestions: false,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _SwitchRow(
                    title: 'Borrar token guardado',
                    subtitle:
                        'Desactiva cobros con link hasta que captures uno nuevo.',
                    value: _clearToken,
                    onChanged: (value) => setState(() => _clearToken = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _PaymentSecurityNote(),
              if (!_isValid) ...[
                const SizedBox(height: 12),
                const _InlineWarning(
                  text:
                      'Las llaves no pueden llevar espacios. Copia el valor completo desde Mercado Pago.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

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

class _PayoutAccountSheet extends ConsumerStatefulWidget {
  const _PayoutAccountSheet({this.account});

  final SellerPayoutAccount? account;

  @override
  ConsumerState<_PayoutAccountSheet> createState() =>
      _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends ConsumerState<_PayoutAccountSheet> {
  final _holderCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late SellerPayoutAccountKind _kind;
  late bool _isDefault;
  var _saving = false;
  var _submitted = false;

  bool get _editing => widget.account != null;
  bool get _numberRequired => !_editing || widget.account!.kind != _kind;
  String get _digits => _onlyDigits(_numberCtrl.text);

  bool get _isValid {
    final holder = _holderCtrl.text.trim();
    return holder.isNotEmpty &&
        holder.length <= 120 &&
        _bankCtrl.text.trim().length <= 80 &&
        _aliasCtrl.text.trim().length <= 80 &&
        _notesCtrl.text.trim().length <= 300 &&
        _isValidPayoutNumber(_kind, _digits, allowEmpty: !_numberRequired);
  }

  String? get _numberHelp {
    if (!_submitted && _numberCtrl.text.trim().isEmpty) {
      return _editing && !_numberRequired
          ? 'Déjalo vacío para conservar el dato guardado.'
          : _kind.helper;
    }
    if (_isValidPayoutNumber(_kind, _digits, allowEmpty: !_numberRequired)) {
      return _kind.helper;
    }
    return switch (_kind) {
      SellerPayoutAccountKind.clabe =>
        'La CLABE debe tener 18 dígitos y pasar la validación bancaria.',
      SellerPayoutAccountKind.debitCard =>
        'La tarjeta de débito debe tener 16 dígitos.',
      SellerPayoutAccountKind.bankAccount =>
        'La cuenta bancaria debe tener entre 6 y 20 dígitos.',
      SellerPayoutAccountKind.phone => 'El celular SPEI debe tener 10 dígitos.',
    };
  }

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _kind = account?.kind ?? SellerPayoutAccountKind.clabe;
    _isDefault = account?.isDefault ?? false;
    if (account != null) {
      _holderCtrl.text = account.holderName;
      _bankCtrl.text = account.bankName ?? '';
      _aliasCtrl.text = account.alias ?? '';
      _notesCtrl.text = account.notes ?? '';
    }
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _bankCtrl.dispose();
    _aliasCtrl.dispose();
    _numberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_isValid || _saving) {
      HapticFeedback.selectionClick();
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(sellerSettingsRepositoryProvider);
      if (widget.account == null) {
        await repo.createPayoutAccount(
          kind: _kind,
          holderName: _holderCtrl.text,
          accountNumber: _numberCtrl.text,
          bankName: _bankCtrl.text,
          alias: _aliasCtrl.text,
          notes: _notesCtrl.text,
          isDefault: _isDefault,
        );
      } else {
        await repo.updatePayoutAccount(
          id: widget.account!.id,
          kind: _kind,
          holderName: _holderCtrl.text,
          accountNumber: _numberCtrl.text.trim().isEmpty
              ? null
              : _numberCtrl.text,
          bankName: _bankCtrl.text,
          alias: _aliasCtrl.text,
          notes: _notesCtrl.text,
          isDefault: _isDefault,
        );
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomSafe + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.ink3.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _IconBadge(icon: _kindIcon(_kind), color: _kindColor(_kind)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _editing ? 'Editar cuenta' : 'Nueva cuenta',
                      style: AppTextStyles.h1.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Captura solo el dato necesario para recibir transferencias.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              _PayoutKindSelector(
                value: _kind,
                onChanged: (value) => setState(() => _kind = value),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _holderCtrl,
                label: 'Titular',
                hint: 'Nombre como aparece en el banco',
                prefixIcon: Symbols.person,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _bankCtrl,
                label: 'Banco o app',
                hint: 'BBVA, Banorte, Spin, Mercado Pago...',
                prefixIcon: Symbols.account_balance,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _numberCtrl,
                label: _numberLabel(_kind),
                hint: _numberHint(_kind, editing: _editing && !_numberRequired),
                prefixIcon: Symbols.pin,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (_numberHelp != null) ...[
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _InlineWarning(
                    key: ValueKey(_numberHelp),
                    icon:
                        _isValidPayoutNumber(
                          _kind,
                          _digits,
                          allowEmpty: !_numberRequired,
                        )
                        ? Symbols.info
                        : Symbols.error,
                    text: _numberHelp!,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppTextField(
                controller: _aliasCtrl,
                label: 'Alias visible',
                hint: 'Principal, Nómina, Apartados...',
                prefixIcon: Symbols.label,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _notesCtrl,
                label: 'Nota para tus clientas',
                hint: 'Ej. Manda comprobante por WhatsApp',
                prefixIcon: Symbols.notes,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _SwitchRow(
                title: 'Usar como principal',
                subtitle: 'Aparecerá primero al compartir datos de pago.',
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: 18),
              PillButton(
                label: _saving ? 'Guardando...' : 'Guardar cuenta',
                icon: _saving ? Symbols.hourglass_top : Symbols.save,
                variant: PillButtonVariant.brand,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutKindSelector extends StatelessWidget {
  const _PayoutKindSelector({required this.value, required this.onChanged});

  final SellerPayoutAccountKind value;
  final ValueChanged<SellerPayoutAccountKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SellerPayoutAccountKind.values.map((kind) {
            return SizedBox(
              width: width,
              child: _PayoutKindTile(
                kind: kind,
                selected: kind == value,
                onTap: () => onChanged(kind),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PayoutKindTile extends StatelessWidget {
  const _PayoutKindTile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final SellerPayoutAccountKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(kind);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? lighten(color, 0.36) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppShadows.small : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_kindIcon(kind), color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                kind.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kind == SellerPayoutAccountKind.clabe
                    ? 'Más segura'
                    : kind == SellerPayoutAccountKind.debitCard
                    ? 'Rápida'
                    : kind == SellerPayoutAccountKind.phone
                    ? 'SPEI'
                    : 'Banco',
                style: AppTextStyles.subtitle.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
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

class _PayoutIntroCard extends StatelessWidget {
  const _PayoutIntroCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            lighten(AppColors.statusRouteFg, 0.35),
            lighten(AppColors.neniDeep, 0.32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Symbols.account_balance_wallet,
                color: AppColors.statusRouteFg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cuentas para recibir pagos',
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Agrega CLABE, tarjeta de débito, cuenta bancaria o celular SPEI. Tus clientas verán datos claros para transferirte.',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Agregar cuenta',
            icon: Symbols.add_card,
            expand: false,
            variant: PillButtonVariant.brand,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _PayoutAccountsSection extends StatelessWidget {
  const _PayoutAccountsSection({
    required this.accounts,
    required this.onAdd,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onDelete,
  });

  final List<SellerPayoutAccount> accounts;
  final VoidCallback onAdd;
  final ValueChanged<SellerPayoutAccount> onEdit;
  final ValueChanged<SellerPayoutAccount> onMakeDefault;
  final ValueChanged<SellerPayoutAccount> onDelete;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return _PayoutEmptyCard(onAdd: onAdd);
    }

    return Column(
      key: const ValueKey('payout-accounts-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transferencias',
                style: AppTextStyles.eyebrow(AppColors.statusRouteFg),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Symbols.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...accounts.map(
          (account) => Padding(
            key: ValueKey(account.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _PayoutAccountCard(
              account: account,
              onEdit: () => onEdit(account),
              onMakeDefault: account.isDefault
                  ? null
                  : () => onMakeDefault(account),
              onDelete: () => onDelete(account),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayoutAccountCard extends StatelessWidget {
  const _PayoutAccountCard({
    required this.account,
    required this.onEdit,
    required this.onDelete,
    this.onMakeDefault,
  });

  final SellerPayoutAccount account;
  final VoidCallback onEdit;
  final VoidCallback? onMakeDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _kindColor(account.kind);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: AppRadii.softRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.softRadius,
            border: Border.all(
              color: account.isDefault
                  ? color.withValues(alpha: 0.32)
                  : AppColors.line,
              width: account.isDefault ? 1.5 : 1,
            ),
            boxShadow: AppShadows.small,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: _kindIcon(account.kind), color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (account.isDefault) ...[
                              const SizedBox(width: 8),
                              _MiniPill(
                                icon: Symbols.star,
                                label: 'Principal',
                                color: color,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account.kindLabel} · ${account.maskedNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.holderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onMakeDefault != null)
                    TextButton(
                      onPressed: onMakeDefault,
                      child: const Text('Hacer principal'),
                    ),
                  PillIconButton(
                    icon: Symbols.edit,
                    size: 40,
                    onPressed: onEdit,
                    iconColor: AppColors.ink2,
                  ),
                  const SizedBox(width: 8),
                  PillIconButton(
                    icon: Symbols.delete,
                    size: 40,
                    onPressed: onDelete,
                    iconColor: AppColors.liveRed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutEmptyCard extends StatelessWidget {
  const _PayoutEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      key: const ValueKey('payout-empty'),
      title: 'Sin cuentas de transferencia',
      subtitle:
          'Agrega al menos una opción para que puedan pagarte sin pedirte datos por chat.',
      children: [
        Row(
          children: [
            const _IconBadge(
              icon: Symbols.account_balance,
              color: AppColors.statusPendingFg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Puedes guardar varias cuentas y marcar una como principal.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PillButton(
          label: 'Agregar primera cuenta',
          icon: Symbols.add,
          expand: false,
          variant: PillButtonVariant.ghost,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _PayoutAccountsLoading extends StatelessWidget {
  const _PayoutAccountsLoading();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      key: const ValueKey('payout-loading'),
      title: 'Cargando cuentas',
      subtitle: 'Estamos revisando tus opciones de transferencia.',
      children: const [LinearProgressIndicator(minHeight: 3)],
    );
  }
}

class _PayoutAccountsError extends StatelessWidget {
  const _PayoutAccountsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      key: const ValueKey('payout-error'),
      title: 'No se pudieron cargar las cuentas',
      subtitle: message,
      children: [
        PillButton(
          label: 'Reintentar',
          icon: Symbols.refresh,
          expand: false,
          variant: PillButtonVariant.ghost,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _PaymentSecurityNote extends StatelessWidget {
  const _PaymentSecurityNote();

  @override
  Widget build(BuildContext context) {
    return const _InlineWarning(
      icon: Symbols.shield_lock,
      text:
          'Nunca captures CVV, NIP ni fecha de vencimiento. Para transferencias solo se necesita el dato destino.',
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.settings});
  final MercadoPagoSettings settings;

  @override
  Widget build(BuildContext context) {
    final configured = settings.isConfigured;
    final color = configured
        ? AppColors.statusDeliveredFg
        : AppColors.statusPendingFg;
    return _SettingsCard(
      title: configured ? 'Cobros activos' : 'Falta conectar pagos',
      subtitle: configured
          ? 'Tu tienda puede cobrar con Mercado Pago.'
          : 'Agrega Public Key y Access Token para activar cobros.',
      children: [
        Row(
          children: [
            _IconBadge(
              icon: configured ? Symbols.check_circle : Symbols.warning,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.publicKey?.trim().isNotEmpty == true
                        ? settings.publicKey!
                        : 'Sin Public Key',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    settings.hasAccessToken
                        ? 'Access Token guardado de forma segura.'
                        : 'No hay token secreto guardado.',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
    super.key,
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
  const _InlineWarning({
    super.key,
    required this.text,
    this.icon = Symbols.info,
  });
  final String text;
  final IconData icon;

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
          Icon(icon, size: 20, color: AppColors.statusPendingFg),
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

bool _hasSpaces(String value) => value.runes.any((rune) => rune == 32);

Color _kindColor(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => AppColors.statusDeliveredFg,
  SellerPayoutAccountKind.debitCard => AppColors.statusRouteFg,
  SellerPayoutAccountKind.bankAccount => AppColors.neniDeep,
  SellerPayoutAccountKind.phone => AppColors.lavender,
};

IconData _kindIcon(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => Symbols.account_balance,
  SellerPayoutAccountKind.debitCard => Symbols.credit_card,
  SellerPayoutAccountKind.bankAccount => Symbols.savings,
  SellerPayoutAccountKind.phone => Symbols.phone_iphone,
};

String _numberLabel(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => 'CLABE interbancaria',
  SellerPayoutAccountKind.debitCard => 'Número de tarjeta',
  SellerPayoutAccountKind.bankAccount => 'Número de cuenta',
  SellerPayoutAccountKind.phone => 'Celular SPEI',
};

String _numberHint(SellerPayoutAccountKind kind, {required bool editing}) {
  if (editing) return 'Déjalo vacío para conservar el actual';
  return switch (kind) {
    SellerPayoutAccountKind.clabe => '032 180 000118359719',
    SellerPayoutAccountKind.debitCard => '1234 5678 9012 3456',
    SellerPayoutAccountKind.bankAccount => '1234567890',
    SellerPayoutAccountKind.phone => '8681234567',
  };
}

String _onlyDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

bool _isValidPayoutNumber(
  SellerPayoutAccountKind kind,
  String digits, {
  required bool allowEmpty,
}) {
  if (allowEmpty && digits.isEmpty) return true;
  return switch (kind) {
    SellerPayoutAccountKind.clabe =>
      digits.length == 18 && _isValidClabe(digits),
    SellerPayoutAccountKind.debitCard => digits.length == 16,
    SellerPayoutAccountKind.phone => digits.length == 10,
    SellerPayoutAccountKind.bankAccount =>
      digits.length >= 6 && digits.length <= 20,
  };
}

bool _isValidClabe(String clabe) {
  if (clabe.length != 18) return false;
  const weights = [3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    final digit = int.tryParse(clabe[i]);
    if (digit == null) return false;
    sum += (digit * weights[i % 3]) % 10;
  }
  final expected = (10 - (sum % 10)) % 10;
  return expected == int.tryParse(clabe[17]);
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

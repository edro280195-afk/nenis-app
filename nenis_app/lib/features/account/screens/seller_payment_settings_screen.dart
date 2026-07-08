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

class SellerPaymentSettingsScreen extends ConsumerStatefulWidget {
  const SellerPaymentSettingsScreen({super.key});

  @override
  ConsumerState<SellerPaymentSettingsScreen> createState() =>
      _SellerPaymentSettingsScreenState();
}

class _SellerPaymentSettingsScreenState
    extends ConsumerState<SellerPaymentSettingsScreen> {
  final _holderCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollController = ScrollController();

  SellerPayoutAccountKind _kind = SellerPayoutAccountKind.clabe;
  MexicanBank _selectedBank = MexicanBank.all.first;
  SellerPayoutAccount? _editing;
  var _isDefault = false;
  var _showForm = false;
  var _submitted = false;
  var _saving = false;
  var _savingMercadoPago = false;
  final _deletingAccountIds = <int>{};
  final _defaultingAccountIds = <int>{};

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _aliasCtrl.dispose();
    _bankNameCtrl.dispose();
    _notesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _digits => _onlyDigits(_accountNumberCtrl.text);

  bool get _isEditingSameKind => _editing != null && _editing!.kind == _kind;

  bool get _numberRequired => !_isEditingSameKind;

  bool get _requiresCustomBank => _selectedBank.id == 'other';

  String get _effectiveBankName {
    final custom = _bankNameCtrl.text.trim();
    if (_requiresCustomBank) return custom;
    return _selectedBank.name;
  }

  bool get _isValid {
    final holder = _holderCtrl.text.trim();
    final bank = _effectiveBankName;
    return holder.isNotEmpty &&
        holder.length <= 120 &&
        bank.isNotEmpty &&
        bank.length <= 80 &&
        _aliasCtrl.text.trim().length <= 80 &&
        _notesCtrl.text.trim().length <= 300 &&
        _isValidPayoutNumber(_kind, _digits, allowEmpty: !_numberRequired);
  }

  void _startNewAccount(List<SellerPayoutAccount> accounts) {
    setState(() {
      _editing = null;
      _kind = SellerPayoutAccountKind.clabe;
      _selectedBank = MexicanBank.all.first;
      _holderCtrl.clear();
      _accountNumberCtrl.clear();
      _aliasCtrl.clear();
      _bankNameCtrl.text = _selectedBank.name;
      _notesCtrl.clear();
      _isDefault = accounts.isEmpty;
      _submitted = false;
      _showForm = true;
    });
    _scrollToForm();
  }

  void _editAccount(SellerPayoutAccount account) {
    setState(() {
      _editing = account;
      _kind = account.kind;
      _selectedBank = account.matchedBank ?? MexicanBank.all.last;
      _holderCtrl.text = account.holderName;
      _accountNumberCtrl.clear();
      _aliasCtrl.text = account.alias ?? '';
      _bankNameCtrl.text = account.bankName ?? _selectedBank.name;
      _notesCtrl.text = account.notes ?? '';
      _isDefault = account.isDefault;
      _submitted = false;
      _showForm = true;
    });
    _scrollToForm();
  }

  void _hideForm() {
    setState(() {
      _editing = null;
      _submitted = false;
      _showForm = false;
    });
  }

  void _scrollToForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_isValid || _saving) {
      if (!_isValid) HapticFeedback.selectionClick();
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(sellerSettingsRepositoryProvider);
      if (_editing == null) {
        await repo.createPayoutAccount(
          kind: _kind,
          holderName: _holderCtrl.text,
          accountNumber: _accountNumberCtrl.text,
          bankName: _effectiveBankName,
          alias: _aliasCtrl.text,
          notes: _notesCtrl.text,
          isDefault: _isDefault,
        );
      } else {
        await repo.updatePayoutAccount(
          id: _editing!.id,
          kind: _kind,
          holderName: _holderCtrl.text,
          accountNumber: _accountNumberCtrl.text.trim().isEmpty
              ? null
              : _accountNumberCtrl.text,
          bankName: _effectiveBankName,
          alias: _aliasCtrl.text,
          notes: _notesCtrl.text,
          isDefault: _isDefault,
        );
      }

      ref.invalidate(sellerPayoutAccountsProvider);
      if (!mounted) return;
      _hideForm();
      _snack(context, 'Cuenta guardada.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount(SellerPayoutAccount account) async {
    if (_deletingAccountIds.contains(account.id) ||
        _defaultingAccountIds.contains(account.id)) {
      return;
    }

    setState(() => _deletingAccountIds.add(account.id));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Eliminar cuenta'),
        content: Text(
          'Se quitará ${account.displayName} de tus métodos de cobro.',
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
    if (!mounted) return;
    if (confirm != true) {
      setState(() => _deletingAccountIds.remove(account.id));
      return;
    }

    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .deletePayoutAccount(account.id);
      ref.invalidate(sellerPayoutAccountsProvider);
      if (mounted && _editing?.id == account.id) _hideForm();
      if (!mounted) return;
      _snack(context, 'Cuenta eliminada.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _deletingAccountIds.remove(account.id));
    }
  }

  Future<void> _setDefault(SellerPayoutAccount account) async {
    if (account.isDefault ||
        _defaultingAccountIds.contains(account.id) ||
        _deletingAccountIds.contains(account.id)) {
      return;
    }

    setState(() => _defaultingAccountIds.add(account.id));
    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .updatePayoutAccount(id: account.id, isDefault: true);
      ref.invalidate(sellerPayoutAccountsProvider);
      if (!mounted) return;
      _snack(context, 'Cuenta principal actualizada.');
      HapticFeedback.selectionClick();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _defaultingAccountIds.remove(account.id));
    }
  }

  Future<void> _copyAccount(SellerPayoutAccount account) async {
    final text = [
      'Datos de pago',
      if ((account.bankName ?? '').trim().isNotEmpty)
        'Banco: ${account.bankName}',
      'Titular: ${account.holderName}',
      '${account.kind.label}: ${account.maskedNumber}',
      if ((account.alias ?? '').trim().isNotEmpty) 'Alias: ${account.alias}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack(context, 'Ficha visible copiada.');
    HapticFeedback.selectionClick();
  }

  Future<void> _configureMercadoPago(MercadoPagoSettings? settings) async {
    if (_savingMercadoPago) return;

    final result = await showModalBottomSheet<_MercadoPagoFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MercadoPagoSettingsSheet(settings: settings),
    );
    if (result == null) return;

    setState(() => _savingMercadoPago = true);
    try {
      await ref
          .read(sellerSettingsRepositoryProvider)
          .updatePaymentSettings(
            publicKey: result.publicKey,
            accessToken: result.accessToken,
            clearAccessToken: result.clearAccessToken,
          );
      ref.invalidate(sellerPaymentSettingsProvider);
      if (!mounted) return;
      _snack(context, 'Mercado Pago actualizado.');
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _snack(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingMercadoPago = false);
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(sellerPayoutAccountsProvider)
      ..invalidate(sellerPaymentSettingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(sellerPayoutAccountsProvider);
    final mercadoPagoAsync = ref.watch(sellerPaymentSettingsProvider);

    final accounts =
        accountsAsync.asData?.value ?? const <SellerPayoutAccount>[];
    final formVisible = _showForm || accounts.isEmpty || _editing != null;
    final canCancelForm = accounts.isNotEmpty || _editing != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      bottomNavigationBar: accountsAsync.hasValue
          ? _PaymentBottomBar(
              formVisible: formVisible,
              saving: _saving,
              enabled: formVisible ? _isValid : true,
              label: formVisible
                  ? (_editing == null ? 'Guardar cuenta' : 'Guardar cambios')
                  : 'Agregar método de cobro',
              icon: formVisible ? Symbols.save : Symbols.add,
              onPrimary: formVisible ? _save : () => _startNewAccount(accounts),
              onCancel: formVisible && canCancelForm ? _hideForm : null,
            )
          : null,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PaymentHeader(
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/account'),
              ),
              Expanded(
                child: accountsAsync.when(
                  loading: () => const _PaymentLoading(),
                  error: (error, _) => _PaymentError(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(sellerPayoutAccountsProvider),
                  ),
                  data: (accounts) {
                    final mercadoPago = mercadoPagoAsync.asData?.value;
                    final mercadoPagoReady = mercadoPago?.isConfigured ?? false;
                    final primary = _primaryAccount(accounts);
                    final pendingCount = mercadoPagoReady ? 0 : 1;
                    final latest = _latestUpdateLabel(accounts);
                    final formVisible =
                        _showForm || accounts.isEmpty || _editing != null;

                    return RefreshIndicator(
                      color: AppColors.neniDeep,
                      onRefresh: _refresh,
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
                        children: [
                          _PaymentSummaryCard(
                            account: primary,
                            accountCount: accounts.length,
                            pendingCount: pendingCount,
                            latestLabel: latest,
                            mercadoPagoReady: mercadoPagoReady,
                            onCopy: primary == null
                                ? null
                                : () => _copyAccount(primary),
                            onShare: primary == null
                                ? null
                                : () => _copyAccount(primary),
                          ),
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: 'Métodos guardados',
                            subtitle: accounts.isEmpty
                                ? 'Agrega la primera cuenta para cobrar.'
                                : 'Ordenados como los ven tus clientas.',
                            actionLabel: accounts.isEmpty ? null : 'Agregar',
                            onAction: accounts.isEmpty
                                ? null
                                : () => _startNewAccount(accounts),
                          ),
                          const SizedBox(height: 10),
                          if (accounts.isEmpty)
                            _EmptyMethodsCard(
                              onAdd: () => _startNewAccount(accounts),
                            )
                          else
                            ...accounts.map((account) {
                              final deleting = _deletingAccountIds.contains(
                                account.id,
                              );
                              final defaulting = _defaultingAccountIds.contains(
                                account.id,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PayoutMethodCard(
                                  account: account,
                                  editing: _editing?.id == account.id,
                                  deleting: deleting,
                                  defaulting: defaulting,
                                  onTap: deleting
                                      ? null
                                      : () => _editAccount(account),
                                  onCopy: deleting
                                      ? null
                                      : () => _copyAccount(account),
                                  onMakeDefault:
                                      account.isDefault ||
                                          deleting ||
                                          defaulting
                                      ? null
                                      : () => _setDefault(account),
                                  onDelete: deleting || defaulting
                                      ? null
                                      : () => _deleteAccount(account),
                                ),
                              );
                            }),
                          _MercadoPagoMethodCard(
                            ready: mercadoPagoReady,
                            busy: _savingMercadoPago,
                            onTap: _savingMercadoPago
                                ? null
                                : () => _configureMercadoPago(mercadoPago),
                          ),
                          const SizedBox(height: 16),
                          _MethodNoteCard(
                            text: primary == null
                                ? 'Cuando agregues una cuenta, Neni la usará como referencia principal para mostrar instrucciones claras de pago.'
                                : 'Por seguridad, las cuentas guardadas se muestran enmascaradas. Para cambiar el número completo, edita la cuenta y escríbelo de nuevo.',
                          ),
                          if (formVisible) ...[
                            const SizedBox(height: 22),
                            _PayoutForm(
                              title: _editing == null
                                  ? 'Agregar cuenta'
                                  : 'Editar cuenta',
                              subtitle: _editing == null
                                  ? 'Solo pedimos lo necesario para compartir datos claros.'
                                  : 'Deja el número vacío si quieres conservar el actual.',
                              kind: _kind,
                              onKindChanged: (kind) {
                                setState(() {
                                  _kind = kind;
                                  _accountNumberCtrl.clear();
                                  _submitted = false;
                                });
                              },
                              selectedBank: _selectedBank,
                              onBankChanged: (bank) {
                                setState(() {
                                  _selectedBank = bank;
                                  _bankNameCtrl.text = bank.id == 'other'
                                      ? ''
                                      : bank.name;
                                });
                              },
                              holderCtrl: _holderCtrl,
                              accountNumberCtrl: _accountNumberCtrl,
                              aliasCtrl: _aliasCtrl,
                              bankNameCtrl: _bankNameCtrl,
                              notesCtrl: _notesCtrl,
                              showCustomBank: _requiresCustomBank,
                              numberRequired: _numberRequired,
                              submitted: _submitted,
                              numberHelp: _numberHelp,
                              isDefault: _isDefault,
                              onDefaultChanged: (value) =>
                                  setState(() => _isDefault = value),
                              onChanged: () => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _numberHelp {
    if (!_submitted && _accountNumberCtrl.text.trim().isEmpty) {
      return _numberRequired
          ? _kind.helper
          : 'Déjalo vacío para conservar el dato guardado.';
    }
    if (_isValidPayoutNumber(_kind, _digits, allowEmpty: !_numberRequired)) {
      return _numberRequired ? _kind.helper : 'Se conservará el número actual.';
    }
    return switch (_kind) {
      SellerPayoutAccountKind.clabe =>
        'La CLABE debe tener 18 dígitos y pasar la validación bancaria.',
      SellerPayoutAccountKind.debitCard =>
        'La tarjeta debe tener 16 dígitos. No pedimos CVV ni vencimiento.',
      SellerPayoutAccountKind.bankAccount =>
        'La cuenta debe tener entre 6 y 20 dígitos.',
      SellerPayoutAccountKind.phone => 'El celular SPEI debe tener 10 dígitos.',
    };
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
      child: Row(
        children: [
          BackIconButton(onPressed: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuentas de cobro',
                  style: AppTextStyles.h1.copyWith(fontSize: 24),
                ),
                Text(
                  'Lo que compartes para que te paguen.',
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
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({
    required this.account,
    required this.accountCount,
    required this.pendingCount,
    required this.latestLabel,
    required this.mercadoPagoReady,
    required this.onCopy,
    required this.onShare,
  });

  final SellerPayoutAccount? account;
  final int accountCount;
  final int pendingCount;
  final String latestLabel;
  final bool mercadoPagoReady;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final ready = account != null;
    final title = ready ? 'Cuenta principal lista' : 'Aún no tienes cuenta';
    final subtitle = ready
        ? 'Esta aparecerá primero al compartir tus datos.'
        : 'Agrega una cuenta para ordenar tus cobros.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF7FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h2),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                icon: ready ? Symbols.check_circle : Symbols.info,
                label: ready ? 'Lista' : 'Pendiente',
                color: ready ? AppColors.statusDeliveredFg : AppColors.gold,
                background: ready
                    ? AppColors.statusDeliveredBg
                    : AppColors.statusPendingBg,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (account == null)
            const _NoPrimaryPreview()
          else
            _BankPreviewCard(account: account!),
          if (account != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Copiar',
                    icon: Symbols.content_copy,
                    expand: true,
                    onPressed: onCopy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    label: 'Compartir',
                    icon: Symbols.ios_share,
                    expand: true,
                    variant: PillButtonVariant.ghost,
                    onPressed: onShare,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: '$accountCount',
                  label: accountCount == 1
                      ? 'Cuenta activa'
                      : 'Cuentas activas',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  value: '$pendingCount',
                  label: pendingCount == 1
                      ? 'Método pendiente'
                      : 'Métodos pendientes',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(value: latestLabel, label: 'Actualizado'),
              ),
            ],
          ),
          if (!mercadoPagoReady) ...[
            const SizedBox(height: 12),
            const _InlineNotice(
              icon: Symbols.info,
              text:
                  'Mercado Pago todavía no está configurado. Tus cuentas bancarias pueden seguir funcionando como respaldo.',
            ),
          ],
        ],
      ),
    );
  }
}

class _BankPreviewCard extends StatelessWidget {
  const _BankPreviewCard({required this.account});

  final SellerPayoutAccount account;

  @override
  Widget build(BuildContext context) {
    final bank = account.matchedBank ?? MexicanBank.all.last;
    final start = colorFromHex(bank.gradientStart);
    final end = colorFromHex(bank.gradientEnd);
    final onPrimary = colorFromHex(bank.onPrimary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.brandSmall(start),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: onPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _BankLogo(bank: bank, compact: true),
                const Spacer(),
                Text(
                  account.kind.label.toUpperCase(),
                  style: AppTextStyles.chip.copyWith(
                    color: onPrimary.withValues(alpha: 0.82),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              account.maskedNumber.isEmpty ? '••••' : account.maskedNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h2.copyWith(
                color: onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PreviewLabel(
                    label: 'Titular',
                    value: account.holderName,
                    color: onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                _PreviewLabel(
                  label: 'Alias',
                  value: account.displayName,
                  color: onPrimary,
                  alignEnd: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.chip.copyWith(
            color: color.withValues(alpha: 0.72),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NoPrimaryPreview extends StatelessWidget {
  const _NoPrimaryPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Symbols.account_balance,
              color: AppColors.ink3,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tu cuenta principal aparecerá aquí',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Así sabrás de inmediato qué datos se compartirán primero.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h2.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _PayoutMethodCard extends StatelessWidget {
  const _PayoutMethodCard({
    required this.account,
    required this.editing,
    required this.deleting,
    required this.defaulting,
    required this.onTap,
    required this.onCopy,
    required this.onMakeDefault,
    required this.onDelete,
  });

  final SellerPayoutAccount account;
  final bool editing;
  final bool deleting;
  final bool defaulting;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bank = account.matchedBank ?? MexicanBank.all.last;
    final color = colorFromHex(bank.primaryColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: account.isDefault
                ? AppColors.statusDeliveredBg.withValues(alpha: 0.34)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: editing
                  ? AppColors.neniDeep
                  : account.isDefault
                  ? AppColors.statusDeliveredFg.withValues(alpha: 0.22)
                  : AppColors.line,
              width: editing ? 1.5 : 1,
            ),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              _BankLogo(bank: bank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bank.name} · ${account.kind.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${account.maskedNumber} · ${account.displayName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (account.isDefault)
                    const _StatusPill(
                      icon: Symbols.star,
                      label: 'Principal',
                      color: AppColors.statusDeliveredFg,
                      background: AppColors.statusDeliveredBg,
                    )
                  else
                    IconButton(
                      tooltip: defaulting
                          ? 'Actualizando...'
                          : 'Hacer principal',
                      onPressed: onMakeDefault,
                      visualDensity: VisualDensity.compact,
                      icon: defaulting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Symbols.star_outline,
                              color: AppColors.ink3,
                              size: 21,
                            ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Copiar ficha',
                        onPressed: onCopy,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Symbols.content_copy,
                          color: color,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip: deleting ? 'Eliminando...' : 'Eliminar',
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                        icon: deleting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Symbols.delete,
                                color: AppColors.liveRed,
                                size: 20,
                              ),
                      ),
                    ],
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

class _MercadoPagoMethodCard extends StatelessWidget {
  const _MercadoPagoMethodCard({
    required this.ready,
    required this.busy,
    required this.onTap,
  });

  final bool ready;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.small,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0085C0), Color(0xFF20B8FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'MP',
                style: AppTextStyles.chip.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mercado Pago link',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ready
                        ? 'Listo para pagos con tarjeta.'
                        : 'Configúralo cuando quieras recibir pagos con tarjeta.',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            _StatusPill(
              icon: ready ? Symbols.check_circle : Symbols.info,
              label: busy
                  ? 'Guardando'
                  : ready
                  ? 'Listo'
                  : 'Falta',
              color: ready ? AppColors.statusDeliveredFg : AppColors.gold,
              background: ready
                  ? AppColors.statusDeliveredBg
                  : AppColors.statusPendingBg,
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Symbols.chevron_right,
                    color: AppColors.ink3,
                    size: 22,
                  ),
          ],
        ),
      ),
    );
  }
}

class _MercadoPagoFormResult {
  const _MercadoPagoFormResult({
    required this.publicKey,
    this.accessToken,
    this.clearAccessToken = false,
  });

  final String publicKey;
  final String? accessToken;
  final bool clearAccessToken;
}

class _MercadoPagoSettingsSheet extends StatefulWidget {
  const _MercadoPagoSettingsSheet({this.settings});

  final MercadoPagoSettings? settings;

  @override
  State<_MercadoPagoSettingsSheet> createState() =>
      _MercadoPagoSettingsSheetState();
}

class _MercadoPagoSettingsSheetState extends State<_MercadoPagoSettingsSheet> {
  late final TextEditingController _publicKeyCtrl;
  late final TextEditingController _accessTokenCtrl;
  var _clearAccessToken = false;
  var _submitted = false;

  @override
  void initState() {
    super.initState();
    _publicKeyCtrl = TextEditingController(
      text: widget.settings?.publicKey ?? '',
    );
    _accessTokenCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _publicKeyCtrl.dispose();
    _accessTokenCtrl.dispose();
    super.dispose();
  }

  bool get _isValid => _publicKeyCtrl.text.trim().isNotEmpty;

  void _submit() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final accessToken = _accessTokenCtrl.text.trim();
    Navigator.of(context).pop(
      _MercadoPagoFormResult(
        publicKey: _publicKeyCtrl.text.trim(),
        accessToken: accessToken.isEmpty ? null : accessToken,
        clearAccessToken: _clearAccessToken && accessToken.isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = widget.settings?.hasAccessToken ?? false;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Configurar Mercado Pago',
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                hasToken
                    ? 'Ya hay un access token guardado. Escribe uno nuevo solo si quieres reemplazarlo.'
                    : 'Agrega tus credenciales para activar pagos con tarjeta.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _publicKeyCtrl,
                label: 'Public key',
                hint: 'APP_USR-...',
                prefixIcon: Symbols.key,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
              ),
              if (_submitted && !_isValid) ...[
                const SizedBox(height: 6),
                Text(
                  'La public key es obligatoria.',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.liveRed,
                    fontSize: 11.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                controller: _accessTokenCtrl,
                label: 'Access token',
                hint: hasToken
                    ? 'Dejalo vacio para conservar el actual'
                    : 'APP_USR-...',
                prefixIcon: Symbols.lock,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) {
                  if (_accessTokenCtrl.text.trim().isNotEmpty &&
                      _clearAccessToken) {
                    _clearAccessToken = false;
                  }
                  setState(() {});
                },
              ),
              if (hasToken) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _clearAccessToken && _accessTokenCtrl.text.isEmpty,
                  onChanged: _accessTokenCtrl.text.trim().isNotEmpty
                      ? null
                      : (value) =>
                            setState(() => _clearAccessToken = value ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.neniDeep,
                  title: Text(
                    'Quitar access token guardado',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Guardar'),
                    ),
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

class _PayoutForm extends StatelessWidget {
  const _PayoutForm({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.onKindChanged,
    required this.selectedBank,
    required this.onBankChanged,
    required this.holderCtrl,
    required this.accountNumberCtrl,
    required this.aliasCtrl,
    required this.bankNameCtrl,
    required this.notesCtrl,
    required this.showCustomBank,
    required this.numberRequired,
    required this.submitted,
    required this.numberHelp,
    required this.isDefault,
    required this.onDefaultChanged,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final SellerPayoutAccountKind kind;
  final ValueChanged<SellerPayoutAccountKind> onKindChanged;
  final MexicanBank selectedBank;
  final ValueChanged<MexicanBank> onBankChanged;
  final TextEditingController holderCtrl;
  final TextEditingController accountNumberCtrl;
  final TextEditingController aliasCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController notesCtrl;
  final bool showCustomBank;
  final bool numberRequired;
  final bool submitted;
  final String numberHelp;
  final bool isDefault;
  final ValueChanged<bool> onDefaultChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final numberIsValid = _isValidPayoutNumber(
      kind,
      _onlyDigits(accountNumberCtrl.text),
      allowEmpty: !numberRequired,
    );
    final numberHasError =
        submitted &&
            !numberIsValid &&
            accountNumberCtrl.text.trim().isNotEmpty ||
        submitted && numberRequired && accountNumberCtrl.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h2),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const _StepBadge(label: '3 pasos'),
            ],
          ),
          const SizedBox(height: 14),
          _KindGrid(value: kind, onChanged: onKindChanged),
          const SizedBox(height: 14),
          _BankSelectorField(
            selectedBank: selectedBank,
            onBankChanged: onBankChanged,
          ),
          if (showCustomBank) ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: bankNameCtrl,
              label: 'Nombre del banco',
              hint: 'Banco o app de pago',
              prefixIcon: Symbols.account_balance,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
            ),
          ],
          const SizedBox(height: 12),
          AppTextField(
            controller: holderCtrl,
            label: 'Titular',
            hint: 'Nombre como aparece en el banco',
            prefixIcon: Symbols.person,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: accountNumberCtrl,
            label: _numberLabel(kind),
            hint: _numberHint(kind, editing: !numberRequired),
            prefixIcon: Symbols.lock,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_maxLength(kind)),
            ],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          _NumberHelp(text: numberHelp, error: numberHasError),
          const SizedBox(height: 12),
          AppTextField(
            controller: aliasCtrl,
            label: 'Alias',
            hint: 'Principal, apartados, débito...',
            prefixIcon: Symbols.sell,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: notesCtrl,
            label: 'Nota privada',
            hint: 'Opcional, solo para ti',
            prefixIcon: Symbols.notes,
            maxLines: 2,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 14),
          _DefaultSwitchCard(value: isDefault, onChanged: onDefaultChanged),
        ],
      ),
    );
  }
}

class _KindGrid extends StatelessWidget {
  const _KindGrid({required this.value, required this.onChanged});

  final SellerPayoutAccountKind value;
  final ValueChanged<SellerPayoutAccountKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.15,
        children: SellerPayoutAccountKind.values.map((kind) {
          final selected = kind == value;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(kind),
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected ? AppShadows.small : const [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _kindIcon(kind),
                      color: selected ? AppColors.ink : AppColors.ink2,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.chip.copyWith(
                          color: selected ? AppColors.ink : AppColors.ink2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BankSelectorField extends StatelessWidget {
  const _BankSelectorField({
    required this.selectedBank,
    required this.onBankChanged,
  });

  final MexicanBank selectedBank;
  final ValueChanged<MexicanBank> onBankChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Banco',
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showBankSheet(context),
            borderRadius: AppRadii.fieldRadius,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.fieldRadius,
                border: Border.all(color: AppColors.line, width: 1.5),
                boxShadow: AppShadows.small,
              ),
              child: Row(
                children: [
                  _BankLogo(bank: selectedBank, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedBank.name,
                      style: AppTextStyles.input.copyWith(fontSize: 14.5),
                    ),
                  ),
                  const Icon(
                    Symbols.expand_more,
                    size: 20,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBankSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BankSheet(
        selectedBank: selectedBank,
        onBankChanged: (bank) {
          onBankChanged(bank);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _BankSheet extends StatefulWidget {
  const _BankSheet({required this.selectedBank, required this.onBankChanged});

  final MexicanBank selectedBank;
  final ValueChanged<MexicanBank> onBankChanged;

  @override
  State<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends State<_BankSheet> {
  final _searchCtrl = TextEditingController();
  List<MexicanBank> _filtered = MexicanBank.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchCtrl.text.toLowerCase().trim();
    final compactQuery = query.replaceAll(' ', '');
    setState(() {
      _filtered = query.isEmpty
          ? MexicanBank.all
          : MexicanBank.all.where((bank) {
              final name = bank.name.toLowerCase();
              return name.contains(query) ||
                  name.replaceAll(' ', '').contains(compactQuery) ||
                  bank.id.toLowerCase().contains(query);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink3.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleccionar banco',
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Symbols.close, color: AppColors.ink2),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SearchField(
              controller: _searchCtrl,
              hint: 'Buscar banco o app',
            ),
          ),
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(14, 0, 14, bottom + 14),
              shrinkWrap: true,
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 62,
                color: AppColors.lineSoft,
              ),
              itemBuilder: (context, index) {
                final bank = _filtered[index];
                final selected = bank.id == widget.selectedBank.id;
                return ListTile(
                  minVerticalPadding: 10,
                  leading: _BankLogo(bank: bank),
                  title: Text(
                    bank.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Symbols.check_circle,
                          color: AppColors.neniDeep,
                        )
                      : null,
                  onTap: () => widget.onBankChanged(bank),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultSwitchCard extends StatelessWidget {
  const _DefaultSwitchCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: value
                ? AppColors.neni.withValues(alpha: 0.08)
                : AppColors.segTrack,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: value
                  ? AppColors.neniDeep.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.neni.withValues(alpha: 0.14)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  value ? Symbols.star : Symbols.star_outline,
                  color: value ? AppColors.neniDeep : AppColors.ink3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usar como principal',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aparece primero cuando compartes datos de pago.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
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
      ),
    );
  }
}

class _PaymentBottomBar extends StatelessWidget {
  const _PaymentBottomBar({
    required this.formVisible,
    required this.saving,
    required this.enabled,
    required this.label,
    required this.icon,
    required this.onPrimary,
    this.onCancel,
  });

  final bool formVisible;
  final bool saving;
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback onPrimary;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final primary = PillButton(
      label: saving ? 'Guardando...' : label,
      icon: saving ? Symbols.hourglass_top : icon,
      variant: PillButtonVariant.primary,
      onPressed: enabled && !saving ? onPrimary : null,
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: AppShadows.nav,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: onCancel == null
              ? primary
              : Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Cancelar',
                        icon: Symbols.close,
                        variant: PillButtonVariant.ghost,
                        onPressed: saving ? null : onCancel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: primary),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _EmptyMethodsCard extends StatelessWidget {
  const _EmptyMethodsCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neni.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Symbols.payments,
              color: AppColors.neniDeep,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Agrega tu primera cuenta',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            'Puedes guardar CLABE, tarjeta de débito, cuenta bancaria o celular SPEI.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Agregar cuenta',
            icon: Symbols.add,
            expand: false,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _MethodNoteCard extends StatelessWidget {
  const _MethodNoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.verified_user, color: AppColors.ink3, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.statusPendingBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.statusPendingFg.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.statusPendingFg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.statusPendingFg,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberHelp extends StatelessWidget {
  const _NumberHelp({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppColors.statusPendingFg
        : AppColors.statusDeliveredFg;
    final bg = error
        ? AppColors.statusPendingBg
        : AppColors.statusDeliveredBg.withValues(alpha: 0.62);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Symbols.error : Symbols.verified_user,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.subtitle.copyWith(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.neni.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          color: AppColors.neniDeep,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _BankLogo extends StatelessWidget {
  const _BankLogo({required this.bank, this.compact = false});

  final MexicanBank bank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 46.0;
    final color = colorFromHex(bank.primaryColor);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorFromHex(bank.gradientStart),
            colorFromHex(bank.gradientEnd),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        boxShadow: AppShadows.brandSmall(color),
      ),
      child: Text(
        _bankInitials(bank.name),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppTextStyles.chip.copyWith(
          color: colorFromHex(bank.onPrimary),
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PaymentLoading extends StatelessWidget {
  const _PaymentLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.neni),
    );
  }
}

class _PaymentError extends StatelessWidget {
  const _PaymentError({required this.message, required this.onRetry});

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
          'No pudimos abrir tus métodos',
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

SellerPayoutAccount? _primaryAccount(List<SellerPayoutAccount> accounts) {
  if (accounts.isEmpty) return null;
  for (final account in accounts) {
    if (account.isDefault) return account;
  }
  return accounts.first;
}

String _latestUpdateLabel(List<SellerPayoutAccount> accounts) {
  if (accounts.isEmpty) return 'Sin datos';
  var latest = accounts.first.updatedAt;
  for (final account in accounts.skip(1)) {
    if (account.updatedAt.isAfter(latest)) latest = account.updatedAt;
  }
  final now = DateTime.now();
  final local = latest.toLocal();
  final sameDay =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  if (sameDay) return 'Hoy';
  return '${local.day}/${local.month}';
}

String _bankInitials(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '?';
  final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length == 1) {
    return words.first.length <= 4
        ? words.first.toUpperCase()
        : words.first.substring(0, 3).toUpperCase();
  }
  return words.take(2).map((w) => w.characters.first).join().toUpperCase();
}

String _numberLabel(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => 'CLABE interbancaria',
  SellerPayoutAccountKind.debitCard => 'Número de tarjeta',
  SellerPayoutAccountKind.bankAccount => 'Número de cuenta',
  SellerPayoutAccountKind.phone => 'Celular SPEI',
};

String _numberHint(SellerPayoutAccountKind kind, {required bool editing}) {
  if (editing) return 'Déjalo vacío para conservar el actual';
  return switch (kind) {
    SellerPayoutAccountKind.clabe => '032180000118359719',
    SellerPayoutAccountKind.debitCard => '1234567890123456',
    SellerPayoutAccountKind.bankAccount => '1234567890',
    SellerPayoutAccountKind.phone => '8681234567',
  };
}

int _maxLength(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => 18,
  SellerPayoutAccountKind.debitCard => 16,
  SellerPayoutAccountKind.bankAccount => 20,
  SellerPayoutAccountKind.phone => 10,
};

IconData _kindIcon(SellerPayoutAccountKind kind) => switch (kind) {
  SellerPayoutAccountKind.clabe => Symbols.account_balance,
  SellerPayoutAccountKind.debitCard => Symbols.credit_card,
  SellerPayoutAccountKind.bankAccount => Symbols.savings,
  SellerPayoutAccountKind.phone => Symbols.phone_iphone,
};

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

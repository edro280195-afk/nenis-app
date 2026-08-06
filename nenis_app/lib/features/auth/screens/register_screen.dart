import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../subscription/data/subscription_models.dart';
import '../../subscription/data/subscription_repository.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_motion.dart';
import '../widgets/legal_acceptance.dart';

/// Alta de clienta o vendedora con correo, teléfono y contraseña.
/// Al enviar, dispara el código de WhatsApp y navega a /confirm.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialRole = FacebookAccountType.client,
  });

  final FacebookAccountType initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();
  final _city = TextEditingController();

  late FacebookAccountType _accountType;
  bool _acceptedLegal = false;
  bool _loading = false;
  String? _errorMessage;

  bool get _isSeller => _accountType == FacebookAccountType.seller;

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialRole;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _businessName.dispose();
    _city.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String email) {
    final at = email.indexOf('@');
    return at > 0 && email.indexOf('.', at) > at + 1 && !email.endsWith('.');
  }

  Future<void> _submit() async {
    if (_loading) return;
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final businessName = _businessName.text.trim();
    final city = _city.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _setError('Escribe tu nombre y tu apellido.');
      return;
    }
    if (!_looksLikeEmail(email)) {
      _setError('Escribe un correo válido.');
      return;
    }
    if (phone.length != 10) {
      _setError('Escribe tu teléfono a 10 dígitos.');
      return;
    }
    if (_password.text.length < 8 || _password.text.length > 128) {
      _setError('La contraseña debe tener entre 8 y 128 caracteres.');
      return;
    }
    if (_isSeller && businessName.isEmpty) {
      _setError('Escribe el nombre de tu negocio.');
      return;
    }
    if (!_acceptedLegal) {
      _setError('Acepta los Términos y el Aviso de privacidad para continuar.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerPhone(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            email: email,
            password: _password.text,
            accountType: _accountType,
            acceptedLegal: _acceptedLegal,
            legalVersion: LegalConfig.currentVersion,
            businessName: _isSeller ? businessName : null,
            city: _isSeller && city.isNotEmpty ? city : null,
          );
      if (mounted) context.go('/confirm');
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SubscriptionPricing> sellerPricing = _isSeller
        ? ref.watch(subscriptionPricingProvider)
        : const AsyncLoading();
    final sellerPricingReady = !_isSeller || sellerPricing.hasValue;
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: AuthMotionColumn(
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackIconButton(
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const NenisLogo(markSize: 46, wordmarkSize: 24),
                  const SizedBox(height: 18),
                  Text(
                    _isSeller
                        ? 'Crea tu cuenta de vendedora'
                        : 'Crea tu cuenta',
                    style: AppTextStyles.h1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSeller
                        ? 'Abre tu tienda con correo, teléfono y contraseña. Facebook es opcional.'
                        : 'Confirmamos tu número por WhatsApp para cuidar tus pedidos.',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 20),
                  _AccountTypeSelector(
                    value: _accountType,
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() {
                              _accountType = value;
                              _errorMessage = null;
                            });
                          },
                  ),
                  if (_isSeller) ...[
                    const SizedBox(height: 16),
                    const _SellerTrialNotice(),
                  ],
                  const SizedBox(height: 20),
                  AppTextField(
                    key: const Key('register-first-name-field'),
                    controller: _firstName,
                    label: 'Nombre',
                    hint: 'Ana',
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    key: const Key('register-last-name-field'),
                    controller: _lastName,
                    label: 'Apellido',
                    hint: 'Lopez',
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    key: const Key('register-email-field'),
                    controller: _email,
                    label: 'Correo',
                    prefixIcon: Symbols.mail,
                    hint: 'tu@correo.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    key: const Key('register-phone-field'),
                    controller: _phone,
                    label: 'Teléfono (WhatsApp)',
                    prefix: '+52',
                    hint: '868 145 22 90',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  const SizedBox(height: 10),
                  _PhoneProtectionNotice(isSeller: _isSeller),
                  const SizedBox(height: 14),
                  PasswordField(
                    key: const Key('register-password-field'),
                    controller: _password,
                    label: 'Contraseña',
                    hint: 'Entre 8 y 128 caracteres',
                    textInputAction: _isSeller
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isSeller) _submit();
                    },
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _isSeller
                        ? Column(
                            key: const ValueKey('seller-fields'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 14),
                              AppTextField(
                                key: const Key('register-business-name-field'),
                                controller: _businessName,
                                label: 'Nombre del negocio',
                                prefixIcon: Symbols.storefront,
                                hint: 'Ej. Regi Bazar',
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.organizationName,
                                ],
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                key: const Key('register-city-field'),
                                controller: _city,
                                label: 'Ciudad (opcional)',
                                prefixIcon: Symbols.location_on,
                                hint: 'Ej. Matamoros',
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.addressCity,
                                ],
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('client-fields')),
                  ),
                  if (_isSeller) ...[
                    const SizedBox(height: 18),
                    _RegistrationPlans(
                      pricing: sellerPricing,
                      onRetry: () =>
                          ref.invalidate(subscriptionPricingProvider),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LegalAcceptanceCheckbox(
                    key: const Key('register-legal-checkbox'),
                    value: _acceptedLegal,
                    enabled: !_loading,
                    onChanged: (value) => setState(() {
                      _acceptedLegal = value;
                      if (value) _errorMessage = null;
                    }),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthFeedbackBanner(
                      key: const Key('register-error'),
                      message: _errorMessage!,
                    ),
                  ],
                  const SizedBox(height: 22),
                  _loading
                      ? const _LoadingButton()
                      : PillButton(
                          label: _isSeller
                              ? 'Iniciar prueba Pro y confirmar'
                              : 'Crear cuenta',
                          icon: Symbols.arrow_forward,
                          onPressed: sellerPricingReady ? _submit : null,
                        ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 13.5,
                          ),
                          children: [
                            const TextSpan(text: '¿Ya tienes cuenta? '),
                            TextSpan(
                              text: 'Inicia sesión',
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.neniDeep,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerTrialNotice extends StatelessWidget {
  const _SellerTrialNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.statusDeliveredBg,
        borderRadius: AppRadii.softRadius,
        border: Border.all(
          color: AppColors.statusDeliveredFg.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.workspace_premium,
            color: AppColors.statusDeliveredFg,
            size: 23,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '14 días gratis en Pro',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.statusDeliveredFg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Por ser tu primera cuenta de vendedora, no pedimos tarjeta ni hacemos un cobro hoy. Al terminar la prueba, tu tienda se bloquea hasta que actives uno de los planes.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneProtectionNotice extends StatelessWidget {
  const _PhoneProtectionNotice({required this.isSeller});

  final bool isSeller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Symbols.verified_user, size: 17, color: AppColors.ink2),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            isSeller
                ? 'Lo confirmaremos por WhatsApp. La prueba es una sola por identidad y dispositivo.'
                : 'Lo confirmaremos por WhatsApp para que sólo tú reclames pedidos, historial y puntos.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _RegistrationPlans extends StatelessWidget {
  const _RegistrationPlans({required this.pricing, required this.onRetry});

  final AsyncValue<SubscriptionPricing> pricing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Conoce los planes antes de empezar',
          style: AppTextStyles.h2.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          'Durante la prueba tendrás las funciones de Pro. Después eliges el plan que mejor te quede.',
          style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        pricing.when(
          loading: () => const _PlansLoading(),
          error: (_, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.softRadius,
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Symbols.cloud_off, color: AppColors.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Necesitamos cargar los precios antes de crear tu tienda.',
                    style: AppTextStyles.body.copyWith(fontSize: 12.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Reintentar',
                  onPressed: onRetry,
                  icon: const Icon(Symbols.refresh),
                ),
              ],
            ),
          ),
          data: (catalog) => Column(
            children: [
              for (final plan in catalog.plans)
                _RegistrationPlanCard(plan: plan),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegistrationPlanCard extends StatelessWidget {
  const _RegistrationPlanCard({required this.plan});

  final PlanPrice plan;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.planTier == 'Pro';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPro ? const Color(0xFFFFEAF2) : AppColors.surface,
        borderRadius: AppRadii.softRadius,
        border: Border.all(
          color: isPro ? AppColors.neni : AppColors.line,
          width: isPro ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPro
                  ? AppColors.neni.withValues(alpha: 0.15)
                  : AppColors.segTrack,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPro ? Symbols.workspace_premium : Symbols.storefront,
              color: isPro ? AppColors.neniDeep : AppColors.ink2,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plan.planTier,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: 6),
                      Text(
                        'TU PRUEBA',
                        style: AppTextStyles.chip.copyWith(
                          color: AppColors.neniDeep,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _summary(plan.planTier),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${plan.monthly.toStringAsFixed(0)}\n${plan.currency}/mes',
            textAlign: TextAlign.right,
            style: AppTextStyles.body.copyWith(
              color: isPro ? AppColors.neniDeep : AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _summary(String tier) => switch (tier) {
    'Pro' => 'En vivos, finanzas, tandas, sorteos y POS',
    'Elite' => 'Todo Pro, C.A.M.I., rutas con tráfico y exportes',
    _ => 'Pedidos, clientas, rastreo, puntos y 1 repartidor',
  };
}

class _PlansLoading extends StatelessWidget {
  const _PlansLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          key: Key('register-plan-loading-$index'),
          height: 68,
          margin: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            color: AppColors.segTrack,
            borderRadius: AppRadii.softRadius,
          ),
        ),
      ),
    );
  }
}

class _AccountTypeSelector extends StatelessWidget {
  const _AccountTypeSelector({required this.value, required this.onChanged});

  final FacebookAccountType value;
  final ValueChanged<FacebookAccountType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountTypeOption(
              key: const Key('register-role-client'),
              label: 'Clienta',
              icon: Symbols.shopping_bag,
              selected: value == FacebookAccountType.client,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(FacebookAccountType.client),
            ),
          ),
          Expanded(
            child: _AccountTypeOption(
              key: const Key('register-role-seller'),
              label: 'Vendedora',
              icon: Symbols.storefront,
              selected: value == FacebookAccountType.seller,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(FacebookAccountType.seller),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeOption extends StatelessWidget {
  const _AccountTypeOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.fieldRadius,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadii.fieldRadius,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.neniDeep : AppColors.ink3,
              fill: selected ? 1 : 0,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: selected ? AppColors.ink : AppColors.ink2,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

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
            strokeWidth: 2.5,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}

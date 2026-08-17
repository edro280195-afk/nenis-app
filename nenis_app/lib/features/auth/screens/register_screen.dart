import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/firebase_phone_auth_service.dart';
import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/phone_number.dart';
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

/// Alta de clienta o vendedora con teléfono y contraseña.
/// Al enviar, dispara el código SMS de Firebase y navega a /confirm.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialRole = AccountType.client});

  final AccountType initialRole;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();
  final _city = TextEditingController();

  late AccountType _accountType;
  bool _acceptedLegal = false;
  bool _loading = false;
  String? _errorMessage;
  bool _finalizing = false;

  bool get _isSeller => _accountType == AccountType.seller;

  Color get _roleAccent => _isSeller ? AppColors.lavender : AppColors.neniDeep;

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialRole;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    _businessName.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final phone = PhoneNumberNormalizer.toE164(_phone.text);
    final businessName = _businessName.text.trim();
    final city = _city.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _setError('Escribe tu nombre y tu apellido.');
      return;
    }
    if (phoneDigits.length != 10 || !PhoneNumberNormalizer.isValidE164(phone)) {
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

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      // Dejamos que la transición del CTA sea visible antes de que Firebase
      // abra el reto de reCAPTCHA en el navegador del teléfono.
      if (!MediaQuery.of(context).disableAnimations) {
        await Future<void>.delayed(const Duration(milliseconds: 260));
      }
      if (!mounted) return;
      final controller = ref.read(authControllerProvider.notifier);
      controller.beginFirebaseAuth(
        phone: phone!,
        profile: FirebaseLoginProfile(
          accountType: _accountType,
          firstName: firstName,
          lastName: lastName,
          password: _password.text,
          businessName: _isSeller ? businessName : null,
          city: _isSeller && city.isNotEmpty ? city : null,
          acceptedLegal: _acceptedLegal,
          legalVersion: LegalConfig.currentVersion,
        ),
      );
      await _sendFirebaseCode(phone);
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

  Future<void> _sendFirebaseCode(String phone) async {
    final service = ref.read(firebasePhoneAuthServiceProvider);
    await service.sendCode(
      phone,
      onCodeSent: () {
        if (_finalizing) return;
        if (mounted) context.go('/confirm');
      },
      onVerificationFailed: (error) {
        _setError(FirebasePhoneAuthService.friendlyMessage(error));
      },
      onVerificationCompleted: _completeCredential,
    );
  }

  Future<void> _completeCredential(PhoneAuthCredential credential) async {
    if (_finalizing) return;
    _finalizing = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final idToken = await ref
          .read(firebasePhoneAuthServiceProvider)
          .signInWithCredential(credential);
      await ref
          .read(authControllerProvider.notifier)
          .loginWithFirebaseIdToken(idToken);
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (_) {
      _setError('No pudimos validar tu teléfono. Inténtalo nuevamente.');
    } finally {
      _finalizing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SubscriptionPricing> sellerPricing = _isSeller
        ? ref.watch(subscriptionPricingProvider)
        : const AsyncLoading();
    final sellerPricingReady = !_isSeller || sellerPricing.hasValue;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 600
                  ? 32.0
                  : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  10,
                  horizontalPadding,
                  34,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: AuthMotionColumn(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BackIconButton(
                            onPressed: _loading
                                ? null
                                : () => context.go('/login'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _RegistrationHero(
                          isSeller: _isSeller,
                          reduceMotion: reduceMotion,
                        ),
                        const SizedBox(height: 20),
                        _RegistrationProgress(accent: _roleAccent),
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
                        const SizedBox(height: 18),
                        _RegistrationSection(
                          icon: Symbols.person,
                          title: 'Tus datos',
                          subtitle:
                              'Usaremos tu teléfono para confirmar la cuenta.',
                          accent: _roleAccent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                key: const Key('register-phone-field'),
                                controller: _phone,
                                label: 'Teléfono celular',
                                prefix: '+52',
                                hint: '868 145 22 90',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                              ),
                              const SizedBox(height: 10),
                              _PhoneProtectionNotice(isSeller: _isSeller),
                              const SizedBox(height: 14),
                              PasswordField(
                                key: const Key('register-password-field'),
                                controller: _password,
                                label: 'Contraseña de acceso',
                                hint: 'Mínimo 8 caracteres',
                                textInputAction: _isSeller
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_isSeller) _submit();
                                },
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _isSeller
                              ? Padding(
                                  key: const ValueKey(
                                    'seller-registration-details',
                                  ),
                                  padding: const EdgeInsets.only(top: 14),
                                  child: _RegistrationSection(
                                    icon: Symbols.storefront,
                                    title: 'Tu tienda',
                                    subtitle:
                                        'Cuéntanos lo esencial para comenzar.',
                                    accent: AppColors.lavender,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        AppTextField(
                                          key: const Key(
                                            'register-business-name-field',
                                          ),
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
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('client-registration-details'),
                                ),
                        ),
                        if (_isSeller) ...[
                          const SizedBox(height: 18),
                          _RegistrationPlans(
                            pricing: sellerPricing,
                            onRetry: () =>
                                ref.invalidate(subscriptionPricingProvider),
                          ),
                        ],
                        const SizedBox(height: 18),
                        LegalAcceptanceCheckbox(
                          key: const Key('register-legal-checkbox'),
                          value: _acceptedLegal,
                          enabled: !_loading,
                          onChanged: (value) => setState(() {
                            _acceptedLegal = value;
                            if (value) _errorMessage = null;
                          }),
                        ),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: _errorMessage == null
                              ? const SizedBox.shrink(
                                  key: ValueKey('no-register-error'),
                                )
                              : Padding(
                                  key: const ValueKey('register-error-visible'),
                                  padding: const EdgeInsets.only(top: 14),
                                  child: AuthFeedbackBanner(
                                    key: const Key('register-error'),
                                    message: _errorMessage!,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final scale = Tween<double>(begin: 0.96, end: 1)
                                .chain(CurveTween(curve: Curves.easeOutBack))
                                .animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: _loading
                              ? _LoadingButton(
                                  key: const ValueKey('register-loading'),
                                  isSeller: _isSeller,
                                  reduceMotion: reduceMotion,
                                )
                              : PillButton(
                                  key: const ValueKey('register-submit'),
                                  label: _isSeller
                                      ? 'Continuar y confirmar teléfono'
                                      : 'Enviar código SMS',
                                  icon: Symbols.arrow_forward,
                                  onPressed: sellerPricingReady
                                      ? _submit
                                      : null,
                                ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: GestureDetector(
                            onTap: _loading ? null : () => context.go('/login'),
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
                                      color: _roleAccent,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero({required this.isSeller, required this.reduceMotion});

  final bool isSeller;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final accent = isSeller ? AppColors.lavender : AppColors.neniDeep;
    final icon = isSeller ? Symbols.storefront : Symbols.shopping_bag;
    final title = isSeller ? 'Abre tu tienda en Nenis' : 'Compra con confianza';
    final subtitle = isSeller
        ? 'Vende tus productos, recibe pedidos y haz crecer tu comunidad.'
        : 'Tu teléfono será tu llave para tus pedidos, puntos y tiendas favoritas.';

    return Column(
      children: [
        const NenisLogo(markSize: 48, wordmarkSize: 24),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: accent, size: 32, fill: 1),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(fontSize: 25),
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProgressStep(
          number: '1',
          label: 'Datos',
          active: true,
          accent: accent,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.line,
          ),
        ),
        _ProgressStep(
          number: '2',
          label: 'Código SMS',
          active: false,
          accent: accent,
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.number,
    required this.label,
    required this.active,
    required this.accent,
  });

  final String number;
  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent : AppColors.segTrack,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: AppTextStyles.body.copyWith(
              color: active ? AppColors.surface : AppColors.ink2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTextStyles.subtitle.copyWith(
            color: active ? AppColors.ink : AppColors.ink2,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RegistrationSection extends StatelessWidget {
  const _RegistrationSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.86),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(13)),
                ),
                child: Icon(icon, color: accent, size: 21, fill: 1),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
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
    final accent = isSeller ? AppColors.lavender : AppColors.neniDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.all(Radius.circular(15)),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.verified_user, size: 18, color: accent, fill: 1),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSeller
                  ? 'Lo confirmaremos por SMS. Una cuenta por identidad y dispositivo.'
                  : 'Lo confirmaremos por SMS para proteger tus pedidos, historial y puntos.',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11.5,
                color: AppColors.ink2,
              ),
            ),
          ),
        ],
      ),
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

  final AccountType value;
  final ValueChanged<AccountType>? onChanged;

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
              accent: AppColors.neniDeep,
              selected: value == AccountType.client,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(AccountType.client),
            ),
          ),
          Expanded(
            child: _AccountTypeOption(
              key: const Key('register-role-seller'),
              label: 'Vendedora',
              icon: Symbols.storefront,
              accent: AppColors.lavender,
              selected: value == AccountType.seller,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(AccountType.seller),
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
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
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
              color: selected ? accent : AppColors.ink3,
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

class _LoadingButton extends StatefulWidget {
  const _LoadingButton({
    super.key,
    required this.isSeller,
    required this.reduceMotion,
  });

  final bool isSeller;
  final bool reduceMotion;

  @override
  State<_LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<_LoadingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (!widget.reduceMotion) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isSeller
        ? const [AppColors.lavender, Color(0xFF7450A8)]
        : const [AppColors.neni, AppColors.neniDeep];

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        gradient: LinearGradient(colors: colors),
        boxShadow: AppShadows.brandPrimary(colors.last),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.isSeller ? 'Preparando tu tienda' : 'Enviando código',
                style: AppTextStyles.button.copyWith(fontSize: 14.5),
              ),
              const SizedBox(width: 4),
              ...List.generate(3, (index) {
                final phase = (_controller.value + index / 3) % 1;
                final opacity = phase < 0.5
                    ? 0.35 + phase * 1.3
                    : 1.0 - (phase - 0.5) * 1.3;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Opacity(
                    opacity: opacity.clamp(0.35, 1.0).toDouble(),
                    child: const Text(
                      '·',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 0.7,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

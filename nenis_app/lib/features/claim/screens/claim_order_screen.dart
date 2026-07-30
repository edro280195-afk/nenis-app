import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/deeplinks/deep_link_service.dart';
import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/pill_button.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/widgets/auth_feedback.dart';
import '../../auth/widgets/legal_acceptance.dart';
import '../data/order_teaser.dart';

/// Onboarding contextual cuando la clienta llega por el enlace del pedido sin
/// sesión: muestra el teaser de confianza y la registra/loguea **passwordless**
/// (teléfono + código), pre-llenando desde el pedido. Al autenticar, el router
/// la lleva sola a `/pedido/{token}` (donde se reclama el pedido).
class ClaimOrderScreen extends ConsumerStatefulWidget {
  const ClaimOrderScreen({super.key});

  @override
  ConsumerState<ClaimOrderScreen> createState() => _ClaimOrderScreenState();
}

enum _Step { phone, code }

class _ClaimOrderScreenState extends ConsumerState<ClaimOrderScreen> {
  final _phone = TextEditingController();
  _Step _step = _Step.phone;
  bool _prefilled = false;
  bool _loading = false;
  bool _acceptedLegal = false;
  String? _error;
  int _otpRevision = 0;

  Timer? _timer;
  int _seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 42);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _sendCode(OrderTeaser teaser) async {
    if (_loading) return;
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (!_acceptedLegal) {
      setState(
        () => _error =
            'Acepta los Terminos y el Aviso de privacidad para continuar.',
      );
      return;
    }
    if (phone.length != 10) {
      setState(() => _error = 'Escribe tu teléfono a 10 dígitos.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordlessOtp(
            phone,
            firstName: teaser.firstName,
            lastName: teaser.lastName,
            acceptedLegal: _acceptedLegal,
            legalVersion: LegalConfig.currentVersion,
          );
      if (!mounted) return;
      setState(() => _step = _Step.code);
      _startCountdown();
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ocurrió un problema inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String code) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyPasswordlessOtp(code);
      // Éxito: el redirect del router lleva sola a /pedido/{token}.
    } on AuthException catch (e) {
      _fail(e.message, resetCode: true);
    } catch (_) {
      _fail(
        'Ocurrió un problema inesperado. Inténtalo de nuevo.',
        resetCode: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _loading) return;
    try {
      await ref.read(authControllerProvider.notifier).resendCode();
      _startCountdown();
      if (mounted) {
        showAuthNotification(
          context,
          'Te enviamos un nuevo código.',
          tone: AuthFeedbackTone.success,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos reenviar el código.');
    }
  }

  void _fail(String message, {bool resetCode = false}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      if (resetCode) _otpRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(pendingDeepLinkProvider);
    if (token == null || token.isEmpty) {
      return _Fallback(onEnter: () => context.go('/login'));
    }
    final teaserAsync = ref.watch(orderTeaserProvider(token));

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: teaserAsync.when(
            loading: () => const _ClaimOrderLoading(),
            error: (_, _) => _Fallback(onEnter: () => context.go('/login')),
            data: (teaser) {
              if (!_prefilled) {
                _prefilled = true;
                final local = teaser.localPhone;
                if (local != null) _phone.text = local;
              }
              return _Content(
                teaser: teaser,
                phone: _phone,
                step: _step,
                loading: _loading,
                acceptedLegal: _acceptedLegal,
                error: _error,
                seconds: _seconds,
                otpRevision: _otpRevision,
                onSend: () => _sendCode(teaser),
                onLegalChanged: (value) => setState(() {
                  _acceptedLegal = value;
                  if (value) _error = null;
                }),
                onCompleted: _verify,
                onResend: _resend,
                onChangeNumber: () => setState(() {
                  _step = _Step.phone;
                  _error = null;
                }),
                onOther: () => context.go('/login'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.teaser,
    required this.phone,
    required this.step,
    required this.loading,
    required this.acceptedLegal,
    required this.error,
    required this.seconds,
    required this.otpRevision,
    required this.onSend,
    required this.onLegalChanged,
    required this.onCompleted,
    required this.onResend,
    required this.onChangeNumber,
    required this.onOther,
  });

  final OrderTeaser teaser;
  final TextEditingController phone;
  final _Step step;
  final bool loading;
  final bool acceptedLegal;
  final String? error;
  final int seconds;
  final int otpRevision;
  final VoidCallback onSend;
  final ValueChanged<bool> onLegalChanged;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );
    final hi = teaser.firstName ?? 'bonita';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Text(
            'Neni’s \u{1F338}',
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(color: AppColors.neniDeep),
          ),
          const SizedBox(height: 18),

          // Teaser de confianza.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.softRadius,
              boxShadow: AppShadows.small,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teaser.businessName.toUpperCase(),
                  style: AppTextStyles.eyebrow(AppColors.neniDeep),
                ),
                const SizedBox(height: 6),
                Text('Hola $hi \u{1F338}', style: AppTextStyles.h2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tu pedido',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.ink2,
                        ),
                      ),
                    ),
                    Text(
                      money.format(teaser.total),
                      style: AppTextStyles.h2.copyWith(fontSize: 20),
                    ),
                  ],
                ),
                if (teaser.statusLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE1EC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      teaser.statusLabel,
                      style: AppTextStyles.chip.copyWith(
                        color: AppColors.neniDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (step == _Step.phone) ...[
            Text(
              'Confirma tu WhatsApp\npara ver y guardar tu pedido',
              style: AppTextStyles.h1.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Sin contraseñas. Te mandamos un código y listo — así siempre lo tendrás a la mano.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 20),
            AppTextField(
              key: const Key('claim-phone-field'),
              controller: phone,
              label: 'Teléfono (WhatsApp)',
              prefix: '🇲🇽 +52',
              hint: '868 145 22 90',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 14),
            LegalAcceptanceCheckbox(
              key: const Key('claim-legal-checkbox'),
              value: acceptedLegal,
              enabled: !loading,
              onChanged: onLegalChanged,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              AuthFeedbackBanner(
                key: const Key('claim-error'),
                message: error!,
              ),
            ],
            const SizedBox(height: 22),
            loading
                ? const _LoadingPill()
                : PillButton(
                    label: 'Enviar código',
                    icon: Symbols.send,
                    onPressed: onSend,
                  ),
          ] else ...[
            Text(
              'Escribe tu código',
              style: AppTextStyles.h1.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Te lo mandamos por WhatsApp al +52 ··· ${_last2(phone.text)}.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onChangeNumber,
              child: Text(
                'Cambiar número',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.neniDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 22),
            OtpInput(
              key: ValueKey('claim-otp-$otpRevision'),
              length: 6,
              onCompleted: onCompleted,
            ),
            const SizedBox(height: 18),
            Center(
              child: seconds > 0
                  ? Text(
                      'Reenvía el código en 0:${seconds.toString().padLeft(2, '0')}',
                      style: AppTextStyles.subtitle,
                    )
                  : GestureDetector(
                      onTap: onResend,
                      child: Text(
                        'Reenviar código',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.neniDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              AuthFeedbackBanner(
                key: const Key('claim-error'),
                message: error!,
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 18),
              const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.neniDeep,
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: onOther,
              child: Text(
                'Entrar con otra cuenta',
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 13,
                  color: AppColors.ink3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _last2(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 2 ? digits.substring(digits.length - 2) : '··';
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
            strokeWidth: 2.5,
            color: AppColors.surface,
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.onEnter});
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.link_off, size: 46, color: AppColors.ink3),
                const SizedBox(height: 14),
                Text(
                  'No pudimos abrir tu pedido',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisa tu enlace o entra a tu cuenta.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 22),
                PillButton(label: "Entrar a Neni's", onPressed: onEnter),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaimOrderLoading extends StatelessWidget {
  const _ClaimOrderLoading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SizedBox(height: 6),
          Skeleton.text(width: 80, height: 16),
          SizedBox(height: 18),
          Skeleton(height: 130, borderRadius: 20),
          SizedBox(height: 22),
          Skeleton.text(width: 200, height: 22),
          SizedBox(height: 8),
          Skeleton.text(width: double.infinity, height: 32),
          SizedBox(height: 20),
          Skeleton(height: 56, borderRadius: 14),
          SizedBox(height: 22),
          Skeleton(height: 56, borderRadius: 28),
        ],
      ),
    );
  }
}

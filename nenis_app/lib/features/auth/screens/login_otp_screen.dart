import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/firebase_phone_auth_service.dart';
import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/phone_number.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_editorial_hero.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_motion.dart';
import '../widgets/legal_acceptance.dart';

/// Login passwordless genérico: teléfono + código por SMS mediante Firebase.
/// Si el telefono no existe, el backend puede crear una cuenta de clienta.
class LoginOtpScreen extends ConsumerStatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  ConsumerState<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

enum _Step { phone, code }

class _LoginOtpScreenState extends ConsumerState<LoginOtpScreen> {
  final _phone = TextEditingController();
  _Step _step = _Step.phone;
  bool _loading = false;
  bool _acceptedLegal = false;
  String? _error;
  int _otpRevision = 0;
  bool _finalizing = false;

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

  Future<void> _sendCode() async {
    if (_loading) return;
    final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final phone = PhoneNumberNormalizer.toE164(_phone.text);
    if (phoneDigits.length != 10 || !PhoneNumberNormalizer.isValidE164(phone)) {
      setState(() => _error = 'Escribe un teléfono válido a 10 dígitos.');
      return;
    }
    if (!_acceptedLegal) {
      setState(
        () => _error =
            'Acepta los Terminos y el Aviso de privacidad para continuar.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      controller.beginFirebaseAuth(
        phone: phone!,
        profile: FirebaseLoginProfile(
          accountType: AccountType.client,
          acceptedLegal: _acceptedLegal,
          legalVersion: LegalConfig.currentVersion,
        ),
      );
      await _sendFirebaseCode(phone, showSuccess: false);
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ocurrio un problema inesperado. Intentalo de nuevo.');
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
      final service = ref.read(firebasePhoneAuthServiceProvider);
      final idToken = await service.verifyCode(code);
      await ref
          .read(authControllerProvider.notifier)
          .loginWithFirebaseIdToken(idToken);
      // Exito: el redirect del router lleva a /home o /pedido/{token}.
    } on AuthException catch (e) {
      _fail(e.message, resetCode: true);
    } catch (_) {
      _fail(
        'Ocurrio un problema inesperado. Intentalo de nuevo.',
        resetCode: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _loading) return;
    final phone = PhoneNumberNormalizer.toE164(_phone.text);
    if (!PhoneNumberNormalizer.isValidE164(phone)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _sendFirebaseCode(phone!, showSuccess: true);
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('No pudimos reenviar el código.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendFirebaseCode(
    String phone, {
    required bool showSuccess,
  }) async {
    final service = ref.read(firebasePhoneAuthServiceProvider);
    await service.sendCode(
      phone,
      onCodeSent: () {
        if (_finalizing) return;
        if (!mounted) return;
        setState(() => _step = _Step.code);
        _startCountdown();
        if (showSuccess) {
          showAuthNotification(
            context,
            'Te enviamos un nuevo código por SMS.',
            tone: AuthFeedbackTone.success,
          );
        }
      },
      onVerificationFailed: (error) {
        _fail(FirebasePhoneAuthService.friendlyMessage(error));
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
        _error = null;
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
      _fail(e.message, resetCode: true);
    } catch (_) {
      _fail(
        'No pudimos validar tu teléfono. Inténtalo de nuevo.',
        resetCode: true,
      );
    } finally {
      _finalizing = false;
      if (mounted) setState(() => _loading = false);
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AuthMotionColumn(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackIconButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: NenisLogo(markSize: 46, wordmarkSize: 23),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      child: _OtpHeroHeader(
                        key: ValueKey(_step),
                        step: _step,
                        last4: _last4(_phone.text),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _OtpProgress(activeCode: _step == _Step.code),
                    const SizedBox(height: 22),
                    if (_step == _Step.phone) ...[
                      AppTextField(
                        key: const Key('login-otp-phone-field'),
                        controller: _phone,
                        label: 'Teléfono celular',
                        prefix: '+52',
                        hint: '868 145 22 90',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumber],
                      ),
                      const SizedBox(height: 14),
                      LegalAcceptanceCheckbox(
                        key: const Key('login-otp-legal-checkbox'),
                        value: _acceptedLegal,
                        enabled: !_loading,
                        onChanged: (value) => setState(() {
                          _acceptedLegal = value;
                          if (value) _error = null;
                        }),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AuthFeedbackBanner(
                          key: const Key('login-otp-error'),
                          message: _error!,
                        ),
                      ],
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: _loading
                            ? const _LoadingPill(
                                key: ValueKey('login-otp-loading'),
                              )
                            : PillButton(
                                key: const Key('login-otp-send'),
                                label: 'Enviar código por SMS',
                                icon: Symbols.arrow_forward,
                                onPressed: _sendCode,
                              ),
                      ),
                    ] else ...[
                      OtpInput(
                        key: ValueKey('login-otp-$_otpRevision'),
                        length: 6,
                        onCompleted: _verify,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Al completar los 6 dígitos verificaremos tu teléfono automáticamente.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Center(
                        child: _seconds > 0
                            ? Text(
                                'Puedes pedir otro código en 0:${_seconds.toString().padLeft(2, '0')}',
                                style: AppTextStyles.subtitle,
                              )
                            : TextButton(
                                onPressed: _resend,
                                child: const Text('Reenviar código'),
                              ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        AuthFeedbackBanner(
                          key: const Key('login-otp-error'),
                          message: _error!,
                        ),
                      ],
                      if (_loading) ...[
                        const SizedBox(height: 18),
                        const _VerifyingPhoneIndicator(),
                      ],
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _step = _Step.phone;
                                  _error = null;
                                }),
                          child: const Text('Cambiar número'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => context.go('/register'),
                        child: const Text('Crear mi cuenta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _last4(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : '····';
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({super.key});

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.surface,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Preparando tu código…',
              style: TextStyle(
                color: AppColors.surface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpHeroHeader extends StatelessWidget {
  const _OtpHeroHeader({super.key, required this.step, required this.last4});

  final _Step step;
  final String last4;

  @override
  Widget build(BuildContext context) {
    final isCode = step == _Step.code;
    return AuthEditorialHero(
      role: AuthHeroRole.client,
      compact: true,
      title: isCode ? 'Tu código llega por SMS' : 'Entra con tu teléfono',
      subtitle: isCode
          ? 'Enviamos un código de 6 dígitos al +52 ··· $last4.'
          : 'Te enviaremos un código seguro. Si es tu primera vez, crearemos tu cuenta de clienta.',
    );
  }
}

class _OtpProgress extends StatelessWidget {
  const _OtpProgress({required this.activeCode});

  final bool activeCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OtpProgressStep(
          label: 'Teléfono',
          number: '1',
          active: !activeCode,
          completed: activeCode,
        ),
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: activeCode ? AppColors.neni : AppColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        _OtpProgressStep(
          label: 'Código SMS',
          number: '2',
          active: activeCode,
          completed: false,
        ),
      ],
    );
  }
}

class _OtpProgressStep extends StatelessWidget {
  const _OtpProgressStep({
    required this.label,
    required this.number,
    required this.active,
    required this.completed,
  });

  final String label;
  final String number;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.neniDeep : AppColors.segTrack,
            shape: BoxShape.circle,
          ),
          child: Text(
            completed ? '✓' : number,
            style: TextStyle(
              color: active ? AppColors.surface : AppColors.ink2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 11.5,
            color: active ? AppColors.ink : AppColors.ink2,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VerifyingPhoneIndicator extends StatelessWidget {
  const _VerifyingPhoneIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neni.withValues(alpha: 0.10),
        borderRadius: AppRadii.softRadius,
        border: Border.all(color: AppColors.neni.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.neniDeep,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Verificando tu teléfono…',
            style: TextStyle(
              color: AppColors.neniDeep,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
import '../widgets/auth_feedback.dart';
import '../widgets/auth_motion.dart';
import '../widgets/auth_otp_notices.dart';
import '../widgets/legal_acceptance.dart';

/// Acceso con teléfono: número y código de 6 dígitos por SMS (Firebase).
/// Si el teléfono no existe, el backend crea una cuenta de clienta.
///
/// Dos pasos en la misma pantalla, sin indicador de progreso (con dos pasos
/// el título ya dice dónde estás). "Atrás" regresa al paso anterior en vez de
/// sacar a la usuaria de la pantalla.
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
      setState(() => _error = 'Escribe tu teléfono a 10 dígitos.');
      return;
    }
    if (!_acceptedLegal) {
      setState(
        () => _error =
            'Acepta los Términos y el Aviso de privacidad para continuar.',
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
      final service = ref.read(firebasePhoneAuthServiceProvider);
      final idToken = await service.verifyCode(code);
      await ref
          .read(authControllerProvider.notifier)
          .loginWithFirebaseIdToken(idToken);
      // Éxito: el redirect del router lleva a /home o /pedido/{token}.
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

  /// "Atrás" deshace un paso: del código vuelve al teléfono, y solo desde el
  /// teléfono sale a la bienvenida.
  void _goBack() {
    if (_loading) return;
    if (_step == _Step.code) {
      _timer?.cancel();
      setState(() {
        _step = _Step.phone;
        _error = null;
        _seconds = 0;
      });
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isCode = _step == _Step.code;

    return PopScope(
      // Sin esto el atrás del sistema sacaba de la pantalla aun estando en el
      // paso del código.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceCream,
        body: NeniBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AuthMotionColumn(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          BackIconButton(onPressed: _loading ? null : _goBack),
                          const Expanded(
                            child: Center(
                              child: NenisLogo(markSize: 34, wordmarkSize: 19),
                            ),
                          ),
                          // Equilibra el botón de atrás para centrar el logo.
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 26),
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        child: AuthTitleBlock(
                          key: ValueKey(_step),
                          title: isCode
                              ? 'Escribe tu código'
                              : 'Entra con tu teléfono',
                          subtitle: isCode
                              ? 'Lo enviamos por SMS al +52 ··· '
                                    '${_last4(_phone.text)}. Puede tardar '
                                    'hasta un minuto en llegar.'
                              : 'Te mandamos un código por SMS. Si es tu '
                                    'primera vez, creamos tu cuenta de '
                                    'clienta.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!isCode) ..._phoneStep() else ..._codeStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return [
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
      const SizedBox(height: 16),
      const OtpExplainer(),
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
        AuthFeedbackBanner(key: const Key('login-otp-error'), message: _error!),
      ],
      const SizedBox(height: 20),
      AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: _loading
            ? const _LoadingPill(
                key: ValueKey('login-otp-loading'),
                label: 'Preparando tu código…',
              )
            : PillButton(
                key: const Key('login-otp-send'),
                label: 'Enviar código por SMS',
                icon: Symbols.arrow_forward,
                onPressed: _sendCode,
              ),
      ),
      if (_loading) ...[const SizedBox(height: 14), const BrowserCheckHint()],
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          key: const Key('login-otp-sell'),
          onPressed: _loading
              ? null
              : () => context.go('/register?role=seller'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(
            '¿Quieres vender en Neni\'s? Crea tu tienda',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.linkAa,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _codeStep() {
    return [
      OtpInput(
        key: ValueKey('login-otp-$_otpRevision'),
        length: 6,
        onCompleted: _verify,
      ),
      const SizedBox(height: 16),
      if (_error != null) ...[
        AuthFeedbackBanner(key: const Key('login-otp-error'), message: _error!),
        const SizedBox(height: 14),
      ],
      if (_loading)
        const _VerifyingPhoneIndicator()
      else
        Center(
          child: _seconds > 0
              ? Text(
                  'Puedes pedir otro código en 0:${_seconds.toString().padLeft(2, '0')}',
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.textAa,
                  ),
                )
              : TextButton(
                  key: const Key('login-otp-resend'),
                  onPressed: _resend,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('Reenviar código'),
                ),
        ),
      const SizedBox(height: 14),
      const OtpExplainer(compact: true),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          key: const Key('login-otp-change-number'),
          onPressed: _loading ? null : _goBack,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Cambiar número'),
        ),
      ),
    ];
  }

  static String _last4(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : '····';
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({super.key, required this.label});

  final String label;

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
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.surface,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
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

class _VerifyingPhoneIndicator extends StatelessWidget {
  const _VerifyingPhoneIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
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
      ),
    );
  }
}

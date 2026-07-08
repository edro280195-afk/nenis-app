import 'dart:async';

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
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/auth_motion.dart';
import '../widgets/legal_acceptance.dart';

/// Login passwordless generico: telefono + codigo por WhatsApp.
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
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      setState(() => _error = 'Escribe tu telefono a 10 digitos.');
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
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordlessOtp(
            phone,
            acceptedLegal: _acceptedLegal,
            legalVersion: LegalConfig.currentVersion,
          );
      if (!mounted) return;
      setState(() => _step = _Step.code);
      _startCountdown();
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
      await ref
          .read(authControllerProvider.notifier)
          .verifyPasswordlessOtp(code);
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
    try {
      await ref.read(authControllerProvider.notifier).resendCode();
      _startCountdown();
      if (mounted) {
        showAuthNotification(
          context,
          'Te enviamos un nuevo codigo.',
          tone: AuthFeedbackTone.success,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos reenviar el codigo.');
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
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: AuthMotionColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                const Center(child: NenisLogo(markSize: 46, wordmarkSize: 23)),
                const SizedBox(height: 18),
                if (_step == _Step.phone) ...[
                  Text(
                    'Entra o crea con codigo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te mandamos un codigo por WhatsApp. Si es tu primera vez, crearemos tu cuenta de clienta.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    key: const Key('login-otp-phone-field'),
                    controller: _phone,
                    label: 'Telefono (WhatsApp)',
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
                  _loading
                      ? const _LoadingPill()
                      : PillButton(
                          key: const Key('login-otp-send'),
                          label: 'Enviar codigo',
                          icon: Symbols.send,
                          onPressed: _sendCode,
                        ),
                ] else ...[
                  Text(
                    'Escribe tu codigo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te lo mandamos por WhatsApp al +52 ... ${_last2(_phone.text)}.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _step = _Step.phone;
                      _error = null;
                    }),
                    child: Text(
                      'Cambiar numero',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.neniDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  OtpInput(
                    key: ValueKey('login-otp-$_otpRevision'),
                    length: 6,
                    onCompleted: _verify,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: _seconds > 0
                        ? Text(
                            'Reenvia el codigo en 0:${_seconds.toString().padLeft(2, '0')}',
                            style: AppTextStyles.subtitle,
                          )
                        : GestureDetector(
                            onTap: _resend,
                            child: Text(
                              'Reenviar codigo',
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.neniDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    AuthFeedbackBanner(
                      key: const Key('login-otp-error'),
                      message: _error!,
                    ),
                  ],
                  if (_loading) ...[
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
                    onTap: () => context.go('/login'),
                    child: Text(
                      'Volver al login',
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 13,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _last2(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 2 ? digits.substring(digits.length - 2) : '..';
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

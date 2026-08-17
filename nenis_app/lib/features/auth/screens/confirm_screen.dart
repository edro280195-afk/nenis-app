import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/firebase_phone_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_feedback.dart';

/// Confirmación del teléfono con el código de 6 dígitos enviado por SMS.
/// Conserva el camino legacy para cuentas que todavía estaban en confirmación
/// por WhatsApp antes de esta migración.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  String _code = '';
  bool _verifying = false;
  bool _resending = false;
  String? _errorMessage;
  int _otpRevision = 0;
  int _seconds = 42;
  Timer? _timer;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 42);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else {
        if (mounted) setState(() => _seconds--);
      }
    });
  }

  String? get _phone => ref.read(authControllerProvider.notifier).pendingPhone;

  Future<void> _verify(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (controller.pendingFirebaseAuth) {
        final idToken = await ref
            .read(firebasePhoneAuthServiceProvider)
            .verifyCode(code);
        await controller.loginWithFirebaseIdToken(idToken);
      } else {
        await controller.confirmPhone(code);
      }
      // Éxito: el redirect del router lleva a /home (o /claim) automáticamente.
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _errorMessage = e.message;
          _code = '';
          _otpRevision++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _errorMessage =
              'Ocurrió un problema inesperado. Inténtalo nuevamente.';
          _code = '';
          _otpRevision++;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resending || _seconds > 0) return;
    setState(() {
      _resending = true;
      _errorMessage = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (controller.pendingFirebaseAuth) {
        final phone = controller.pendingPhone;
        if (phone == null) throw AuthException('Escribe tu teléfono de nuevo.');
        await ref
            .read(firebasePhoneAuthServiceProvider)
            .sendCode(
              phone,
              onCodeSent: () {},
              onVerificationFailed: (error) {
                if (mounted) {
                  setState(
                    () => _errorMessage =
                        FirebasePhoneAuthService.friendlyMessage(error),
                  );
                }
              },
              onVerificationCompleted: _completeCredential,
            );
      } else {
        await controller.resendCode();
      }
      _startCountdown();
      if (mounted) {
        showAuthNotification(
          context,
          'Solicitamos un nuevo código por SMS.',
          tone: AuthFeedbackTone.success,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'No pudimos solicitar otro código. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _maskedPhone {
    final p = _phone;
    if (p == null || p.length < 4) return 'tu teléfono';
    return '+52 ··· ${p.substring(p.length - 4)}';
  }

  Future<void> _completeCredential(PhoneAuthCredential credential) async {
    if (_finalizing) return;
    _finalizing = true;
    if (mounted) setState(() => _verifying = true);
    try {
      final idToken = await ref
          .read(firebasePhoneAuthServiceProvider)
          .signInWithCredential(credential);
      await ref
          .read(authControllerProvider.notifier)
          .loginWithFirebaseIdToken(idToken);
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'No pudimos validar tu teléfono. Inténtalo nuevamente.',
        );
      }
    } finally {
      _finalizing = false;
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BackIconButton(
                      onPressed: () => context.go('/login'),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD6F8DE), Color(0xFFB8F0C6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Symbols.chat,
                      color: Color(0xFF128C4B),
                      size: 40,
                      fill: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      Text(
                        'Confirma tu número',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escribe el código de 6 dígitos que te enviamos por SMS a $_maskedPhone',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle,
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Cambiar número',
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.neniDeep,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: OtpInput(
                    key: ValueKey('confirm-otp-$_otpRevision'),
                    length: 6,
                    onCompleted: (code) {
                      _code = code;
                      _verify(code);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: _resending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.neniDeep,
                          ),
                        )
                      : _seconds > 0
                      ? Text(
                          'Reenvía el código en 0:${_seconds.toString().padLeft(2, '0')}',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 13.5,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: Text(
                            'Reenviar código',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 13.5,
                              color: AppColors.neniDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: AuthFeedbackBanner(
                      key: const Key('confirm-error'),
                      message: _errorMessage!,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (ref.read(authControllerProvider.notifier).pendingDevMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3ECFF),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Symbols.construction,
                            size: 18,
                            color: Color(0xFF6A4DBB),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Modo prueba — usa el código 000000',
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 12.5,
                              color: const Color(0xFF6A4DBB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _verifying
                      ? const _ConfirmLoadingButton()
                      : PillButton(
                          label: 'Confirmar',
                          icon: Symbols.check,
                          onPressed: _code.length == 6
                              ? () => _verify(_code)
                              : null,
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmLoadingButton extends StatelessWidget {
  const _ConfirmLoadingButton();

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

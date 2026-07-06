import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/storage/credential_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/pill_button.dart';
import '../widgets/auth_feedback.dart';

enum _PasswordResetStep { request, confirm, success }

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _phone = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _PasswordResetStep _step = _PasswordResetStep.request;
  OtpRequestResult? _otpResult;
  String _code = '';
  String? _error;
  bool _loading = false;
  bool _resending = false;
  int _otpRevision = 0;
  int _seconds = 0;
  Timer? _timer;

  String get _normalizedPhone => _phone.text.replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
        return;
      }
      setState(() => _seconds--);
    });
  }

  Future<void> _requestCode() async {
    if (_loading) return;
    final phone = _normalizedPhone;
    if (phone.length != 10) {
      _setError('Escribe tu teléfono a 10 dígitos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(phone);
      if (!mounted) return;
      setState(() {
        _otpResult = result;
        _step = _PasswordResetStep.confirm;
      });
      _startCountdown();
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_loading) return;
    if (_code.length != 6) {
      _setError('Escribe el código completo de 6 dígitos.');
      return;
    }
    if (_newPassword.text.length < 8 || _newPassword.text.length > 128) {
      _setError('La contraseña debe tener entre 8 y 128 caracteres.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _setError('Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            phone: _normalizedPhone,
            code: _code,
            newPassword: _newPassword.text,
          );
      await ref.read(credentialStorageProvider).clear();
      if (!mounted) return;
      _timer?.cancel();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _step = _PasswordResetStep.success);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _code = '';
        _otpRevision++;
      });
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resending || _seconds > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_normalizedPhone);
      if (!mounted) return;
      setState(() => _otpResult = result);
      _startCountdown();
      showAuthNotification(
        context,
        'Solicitamos un nuevo código para tu WhatsApp.',
        tone: AuthFeedbackTone.success,
      );
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('No pudimos solicitar otro código. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _back() {
    if (_loading || _resending) return;
    if (_step == _PasswordResetStep.confirm) {
      _timer?.cancel();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {
        _step = _PasswordResetStep.request;
        _otpResult = null;
        _error = null;
        _code = '';
        _seconds = 0;
        _otpRevision++;
      });
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackIconButton(onPressed: _back),
                    ),
                    const SizedBox(height: 14),
                    const NenisLogo(markSize: 46, wordmarkSize: 24),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: switch (_step) {
                        _PasswordResetStep.request => _buildRequest(),
                        _PasswordResetStep.confirm => _buildConfirm(),
                        _PasswordResetStep.success => _buildSuccess(),
                      },
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

  Widget _buildRequest() {
    return Column(
      key: const ValueKey(_PasswordResetStep.request),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recupera tu acceso', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Te enviaremos un código por WhatsApp al teléfono verificado de tu cuenta.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('reset-phone-field'),
          controller: _phone,
          label: 'Teléfono',
          prefix: '+52',
          hint: '868 145 22 90',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          onSubmitted: (_) => _requestCode(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthFeedbackBanner(
            key: const Key('password-reset-error'),
            message: _error!,
          ),
        ],
        const SizedBox(height: 22),
        _ResetActionButton(
          key: const Key('request-reset-code-button'),
          label: 'Enviar código',
          icon: Symbols.arrow_forward,
          loading: _loading,
          onPressed: _loading ? null : _requestCode,
        ),
        const SizedBox(height: 12),
        Text(
          'Por seguridad, la respuesta será la misma aunque el número no esté registrado.',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.ink3,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirm() {
    final phone = _normalizedPhone;
    final masked = phone.length >= 2
        ? '+52 ··· ${phone.substring(phone.length - 2)}'
        : 'tu WhatsApp';

    return Column(
      key: const ValueKey(_PasswordResetStep.confirm),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revisa tu WhatsApp', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Escribe el código enviado a $masked y elige una contraseña nueva.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 18),
        if (_otpResult != null)
          AuthFeedbackBanner(
            message: _otpResult!.message,
            tone: AuthFeedbackTone.info,
          ),
        const SizedBox(height: 20),
        OtpInput(
          key: ValueKey('password-reset-otp-$_otpRevision'),
          length: 6,
          onCompleted: (code) => setState(() => _code = code),
        ),
        const SizedBox(height: 18),
        PasswordField(
          key: const Key('reset-new-password-field'),
          controller: _newPassword,
          label: 'Nueva contraseña',
          hint: 'Entre 8 y 128 caracteres',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('reset-confirm-password-field'),
          controller: _confirmPassword,
          label: 'Confirma la contraseña',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmReset(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthFeedbackBanner(
            key: const Key('password-reset-error'),
            message: _error!,
          ),
        ],
        const SizedBox(height: 22),
        _ResetActionButton(
          key: const Key('confirm-password-reset-button'),
          label: 'Actualizar contraseña',
          icon: Symbols.lock_reset,
          loading: _loading,
          onPressed: _loading ? null : _confirmReset,
        ),
        const SizedBox(height: 12),
        Center(
          child: _resending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.neniDeep,
                  ),
                )
              : TextButton(
                  onPressed: _seconds == 0 ? _resendCode : null,
                  child: Text(
                    _seconds > 0
                        ? 'Solicitar otro código en $_seconds s'
                        : 'Solicitar otro código',
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey(_PasswordResetStep.success),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.statusDeliveredBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.check_circle,
              color: AppColors.statusDeliveredFg,
              size: 42,
              fill: 1,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Contraseña actualizada', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Ya puedes iniciar sesión o volver a vincular tu cuenta con Facebook.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 24),
        PillButton(
          key: const Key('password-reset-success-button'),
          label: 'Volver a iniciar sesión',
          icon: Symbols.arrow_forward,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}

class _ResetActionButton extends StatelessWidget {
  const _ResetActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return PillButton(label: label, icon: icon, onPressed: onPressed);
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.neniDeep,
        borderRadius: AppRadii.pillRadius,
      ),
      alignment: Alignment.center,
      child: const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.surface,
        ),
      ),
    );
  }
}

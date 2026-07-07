import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_repository.dart';
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

enum _PasswordResetStep { request, verifyOtp, newPassword, success }

enum PasswordStrength { weak, medium, strong }

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
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  _PasswordResetStep _step = _PasswordResetStep.request;
  OtpRequestResult? _otpResult;
  String _code = '';
  String? _error;
  bool _loading = false;
  bool _resending = false;
  int _otpRevision = 0;
  int _seconds = 0;
  Timer? _timer;

  // Mock WhatsApp Notification States
  bool _showWaToast = false;
  bool _waToastVisible = false;
  String _waCode = '';
  Timer? _waToastTimer;

  String get _normalizedPhone => _phone.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    _newPassword.addListener(_onPasswordChanged);
    _confirmPassword.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _newPassword.removeListener(_onPasswordChanged);
    _confirmPassword.removeListener(_onPasswordChanged);
    _timer?.cancel();
    _waToastTimer?.cancel();
    _phone.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 45);
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
        _step = _PasswordResetStep.verifyOtp;
      });
      _startCountdown();

      // Trigger simulated WhatsApp toast if devMode is enabled
      if (result.devMode) {
        _waToastTimer?.cancel();
        setState(() {
          _waCode = '000000';
          _showWaToast = true;
          _waToastVisible = false;
        });
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() => _waToastVisible = true);
          }
        });

        _waToastTimer = Timer(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() => _waToastVisible = false);
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() => _showWaToast = false);
              }
            });
          }
        });
      }
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _autoFillOtp() {
    _waToastTimer?.cancel();
    setState(() {
      _waToastVisible = false;
      _code = _waCode;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showWaToast = false);
    });
    
    // Auto advance to Step 3 (New Password) with standard delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _step = _PasswordResetStep.newPassword;
        });
      }
    });
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
      if (!mounted) return;
      _timer?.cancel();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _step = _PasswordResetStep.success);
    } on AuthException catch (error) {
      if (!mounted) return;
      
      // If code error, transition back to verifyOtp step and shake
      final isCodeError = error.message.toLowerCase().contains('código') ||
                          error.message.toLowerCase().contains('code') ||
                          error.message.toLowerCase().contains('incorrecto') ||
                          error.message.toLowerCase().contains('expirado');
      if (isCodeError) {
        setState(() {
          _step = _PasswordResetStep.verifyOtp;
          _error = error.message;
          _code = '';
          _otpRevision++;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          _shakeKey.currentState?.shake();
        });
      } else {
        _setError(error.message);
      }
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
    if (_step == _PasswordResetStep.verifyOtp) {
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
    if (_step == _PasswordResetStep.newPassword) {
      setState(() {
        _step = _PasswordResetStep.verifyOtp;
        _error = null;
      });
      return;
    }
    context.go('/login');
  }

  PasswordStrength _checkStrength(String password) {
    if (password.length < 8) return PasswordStrength.weak;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]')) || password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]')) && password.length >= 10) score++;
    
    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              SingleChildScrollView(
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
                          child: _step == _PasswordResetStep.success
                              ? const SizedBox(height: 44) // No back button on success step
                              : BackIconButton(onPressed: _back),
                        ),
                        const SizedBox(height: 14),
                        const NenisLogo(markSize: 46, wordmarkSize: 24),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.15, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: switch (_step) {
                            _PasswordResetStep.request => _buildRequest(),
                            _PasswordResetStep.verifyOtp => _buildVerifyOtp(),
                            _PasswordResetStep.newPassword => _buildNewPassword(),
                            _PasswordResetStep.success => _buildSuccess(),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showWaToast) _buildWaToast(),
            ],
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
        const Align(
          alignment: Alignment.centerLeft,
          child: _StepIconBadge(icon: Symbols.vpn_key),
        ),
        const SizedBox(height: 16),
        Text('¿Olvidaste tu contraseña?', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Escribe tu número de teléfono celular. Te mandaremos un código por WhatsApp para restaurar tu contraseña al instante.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('reset-phone-field'),
          controller: _phone,
          label: 'Teléfono celular',
          prefix: '+52',
          hint: '868 145 22 90',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          onSubmitted: (_) => _requestCode(),
          onChanged: (_) => setState(() {}),
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
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              'Volver a iniciar sesión',
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtp() {
    final phone = _normalizedPhone;
    final masked = phone.length >= 2
        ? '+52 ··· ${phone.substring(phone.length - 2)}'
        : 'tu WhatsApp';

    return Column(
      key: const ValueKey(_PasswordResetStep.verifyOtp),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: _StepIconBadge(icon: Symbols.sms),
        ),
        const SizedBox(height: 16),
        Text('Revisa tu WhatsApp', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Acabamos de enviar un código de verificación de 6 dígitos a $masked.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 24),
        ShakeWidget(
          key: _shakeKey,
          child: OtpInput(
            key: ValueKey('password-reset-otp-$_otpRevision'),
            length: 6,
            onCompleted: (code) {
              setState(() => _code = code);
              // Auto advance to password creation
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted && _code.length == 6) {
                  setState(() => _step = _PasswordResetStep.newPassword);
                }
              });
            },
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AuthFeedbackBanner(
            key: const Key('password-reset-error'),
            message: _error!,
          ),
        ],
        const SizedBox(height: 24),
        if (_otpResult?.devMode == true) ...[
          Container(
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
          const SizedBox(height: 20),
        ],
        Center(
          child: _resending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.neniDeep,
                  ),
                )
              : RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.subtitle.copyWith(fontSize: 13, color: AppColors.ink2),
                    children: [
                      if (_seconds > 0) ...[
                        const TextSpan(text: '¿No lo recibiste?\nReenviar código en '),
                        TextSpan(
                          text: '$_seconds s',
                          style: const TextStyle(color: AppColors.neniDeep, fontWeight: FontWeight.w600),
                        ),
                      ] else ...[
                        const TextSpan(text: '¿No lo recibiste?\n'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: _resendCode,
                            child: Text(
                              'Reenviar código ahora',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neniDeep,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNewPassword() {
    final p1 = _newPassword.text;
    final p2 = _confirmPassword.text;
    final isEnabled = p1.length >= 8 && p1 == p2;

    return Column(
      key: const ValueKey(_PasswordResetStep.newPassword),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: _StepIconBadge(icon: Symbols.lock),
        ),
        const SizedBox(height: 16),
        Text('Nueva contraseña', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Crea una contraseña segura de al menos 8 caracteres para mantener protegida tu cuenta.',
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 24),
        PasswordField(
          key: const Key('reset-new-password-field'),
          controller: _newPassword,
          label: 'Contraseña nueva',
          hint: 'Mínimo 8 caracteres',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('reset-confirm-password-field'),
          controller: _confirmPassword,
          label: 'Confirmar contraseña',
          hint: 'Repite tu contraseña',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isEnabled ? _confirmReset() : null,
        ),
        const SizedBox(height: 14),
        _buildStrengthMeter(p1),
        const SizedBox(height: 14),
        _buildChecklist(p1, p2),
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
          icon: Symbols.done_all,
          loading: _loading,
          onPressed: isEnabled ? _confirmReset : null,
        ),
      ],
    );
  }

  Widget _buildStrengthMeter(String password) {
    final strength = _checkStrength(password);
    Color color;
    double widthPercent;
    String label;

    if (password.isEmpty) {
      color = AppColors.line;
      widthPercent = 0.0;
      label = 'Muy débil';
    } else {
      switch (strength) {
        case PasswordStrength.weak:
          color = const Color(0xFFFF4D4D);
          widthPercent = 0.33;
          label = 'Débil';
          break;
        case PasswordStrength.medium:
          color = const Color(0xFFF3B341);
          widthPercent = 0.66;
          label = 'Intermedia';
          break;
        case PasswordStrength.strong:
          color = AppColors.statusDeliveredFg;
          widthPercent = 1.0;
          label = 'Segura 🌸';
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthPercent,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seguridad:',
              style: AppTextStyles.subtitle.copyWith(fontSize: 11, color: AppColors.ink2),
            ),
            Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: password.isEmpty ? AppColors.ink3 : color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklist(String p1, String p2) {
    final isLengthOk = p1.length >= 8;
    final isMatchOk = p1.isNotEmpty && p1 == p2;

    return Column(
      children: [
        _buildCheckItem('Mínimo 8 caracteres', isLengthOk),
        const SizedBox(height: 6),
        _buildCheckItem('Las contraseñas coinciden', isMatchOk),
      ],
    );
  }

  Widget _buildCheckItem(String text, bool checked) {
    return Row(
      children: [
        Icon(
          Symbols.check_circle,
          size: 16,
          color: checked ? AppColors.statusDeliveredFg : AppColors.ink3,
          fill: checked ? 1.0 : 0.0,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 12,
            color: checked ? AppColors.statusDeliveredFg : AppColors.ink2,
            decoration: checked ? TextDecoration.lineThrough : null,
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
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.statusDeliveredBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.check_circle,
              color: AppColors.statusDeliveredFg,
              size: 48,
              fill: 1,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          '¡Listo, hermosa!',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 10),
        Text(
          'Tu contraseña ha sido actualizada correctamente. Tu cuenta está segura y lista para usarse.',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 32),
        PillButton(
          key: const Key('password-reset-success-button'),
          label: 'Entrar a mi cuenta',
          icon: Symbols.login,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }

  Widget _buildWaToast() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: _waToastVisible ? 16 : -140,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: _autoFillOtp,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x223A2233),
                offset: Offset(0, 16),
                blurRadius: 36,
              ),
            ],
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D25D366),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.chat,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'WhatsApp · Neni\'s',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'ahora',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 11,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu código Neni\'s es ${_waCode.isNotEmpty ? _waCode : "000000"}. Válido por 10 minutos. 🌸',
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
      ),
    );
  }
}

class _StepIconBadge extends StatelessWidget {
  const _StepIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF0F5),
            Color(0xFFFFE1EB),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AD6336C),
            offset: Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 28,
        color: AppColors.neniDeep,
      ),
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

class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double translation = 16.0 *
            math.sin(_controller.value * 4 * math.pi) *
            (1.0 - _controller.value);

        return Transform.translate(
          offset: Offset(translation, 0),
          child: widget.child,
        );
      },
    );
  }
}

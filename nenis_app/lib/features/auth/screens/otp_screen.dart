import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/otp_cell.dart';
import '../../../shared/widgets/pill_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _code = '';
  bool _verifying = false;
  int _seconds = 42;
  Timer? _timer;

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
    setState(() => _verifying = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(code);
      // Éxito: el redirect del router lleva a /home automáticamente.
    } on AuthException catch (e) {
      if (mounted) {
        _toast(e.message);
        setState(() => _verifying = false);
      }
    } catch (_) {
      if (mounted) {
        _toast('No pudimos conectar. Revisa tu internet.');
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _resend() async {
    final phone = _phone;
    if (phone == null) return;
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(phone);
      _startCountdown();
      _toast('Te reenviamos el código 💌');
    } catch (_) {
      _toast('No pudimos reenviar. Intenta de nuevo.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _maskedPhone {
    final p = _phone;
    if (p == null || p.length < 2) return 'tu teléfono';
    return '+52 ··· ${p.substring(p.length - 2)}';
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
                        colors: [Color(0xFFFFE1EC), Color(0xFFFFD0E2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Symbols.sms,
                      color: AppColors.neniDeep,
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
                        'Verifica tu número',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escribe el código de 6 dígitos que mandamos por SMS a $_maskedPhone',
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
                    length: 6,
                    onCompleted: (code) {
                      _code = code;
                      _verify(code);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: _seconds > 0
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
                const SizedBox(height: 18),
                if (ref.read(authControllerProvider.notifier).pendingOtpDevMode)
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
                      ? const _OtpLoadingButton()
                      : PillButton(
                          label: 'Verificar',
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

class _OtpLoadingButton extends StatelessWidget {
  const _OtpLoadingButton();

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

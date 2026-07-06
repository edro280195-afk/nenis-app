import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/pill_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _fbLoading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      _toast('Escribe tu teléfono a 10 dígitos 🌸');
      return;
    }
    if (_password.text.isEmpty) {
      _toast('Escribe tu contraseña');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginPhone(phone, _password.text);
      // Éxito: el redirect del router lleva a /home automáticamente.
    } on PhoneNotVerifiedException catch (e) {
      if (mounted) {
        _toast(e.message);
        context.go('/confirm');
      }
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('No pudimos conectar. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facebookLogin() async {
    if (_fbLoading) return;
    setState(() => _fbLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).loginFacebook();
      // Éxito: el redirect del router lleva a /home automáticamente.
    } on FacebookCancelledException {
      // La usuaria canceló: no mostramos error.
    } on FacebookNeedsPhoneException {
      if (mounted) await _askPhoneForFacebook();
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('No pudimos conectar. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _fbLoading = false);
    }
  }

  /// Pide el teléfono cuando Facebook crea una cuenta nueva (lo exige el backend).
  Future<void> _askPhoneForFacebook() async {
    final phoneCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 22,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Un paso más 💕', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Déjanos tu teléfono para terminar tu cuenta y avisarte de tus pedidos.',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: phoneCtrl,
                    prefix: '🇲🇽 +52',
                    hint: '868 145 22 90',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),
                  PillButton(
                    label: saving ? 'Guardando…' : 'Continuar',
                    onPressed: saving
                        ? null
                        : () async {
                            final phone =
                                phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                            if (phone.length < 10) {
                              _toast('Escribe tu teléfono a 10 dígitos');
                              return;
                            }
                            setSheet(() => saving = true);
                            try {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .completeFacebookWithPhone(phone);
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            } on AuthException catch (e) {
                              setSheet(() => saving = false);
                              _toast(e.message);
                            } catch (_) {
                              setSheet(() => saving = false);
                              _toast('No pudimos conectar. Revisa tu internet.');
                            }
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
    phoneCtrl.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: NeniBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const NenisLogo(markSize: 52, wordmarkSize: 28),
                  const SizedBox(height: 4),
                  const _LoginHero(),
                  const SizedBox(height: 6),
                  Text(
                    'Hola de nuevo 💕',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Entra con tu teléfono y contraseña para ver tus pedidos, puntos y lives.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 22),
                  AppTextField(
                    controller: _phone,
                    prefix: '🇲🇽 +52',
                    hint: '868 145 22 90',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _password,
                    hint: 'Tu contraseña',
                    onSubmitted: (_) => _continue(),
                  ),
                  const SizedBox(height: 18),
                  _loading
                      ? const _LoadingButton()
                      : PillButton(
                          label: 'Entrar',
                          icon: Symbols.arrow_forward,
                          onPressed: _continue,
                        ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/register'),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13.5),
                          children: [
                            const TextSpan(text: '¿Primera vez? '),
                            TextSpan(
                              text: 'Crea tu cuenta',
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
                  const SizedBox(height: 18),
                  _divider(),
                  const SizedBox(height: 18),
                  PillButton(
                    label: _fbLoading ? 'Conectando…' : 'Entrar con Facebook',
                    icon: Symbols.thumb_up,
                    variant: PillButtonVariant.facebook,
                    onPressed: _fbLoading ? null : _facebookLogin,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Al continuar aceptas los Términos y el Aviso de privacidad.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _showTeamLogin,
                      child: Text(
                        'Acceso de equipo',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.neniDeep,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
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

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
      ],
    );
  }

  void _showTeamLogin() {
    final email = TextEditingController();
    final pass = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Acceso de equipo', style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'Para administradoras y conductores con correo.',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: email,
                prefixIcon: Symbols.mail,
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              PasswordField(controller: pass),
              const SizedBox(height: 18),
              PillButton(
                label: 'Entrar',
                onPressed: () async {
                  try {
                    await ref
                        .read(authControllerProvider.notifier)
                        .loginEmail(email.text.trim(), pass.text);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } on AuthException catch (e) {
                    _toast(e.message);
                  } catch (_) {
                    _toast('No pudimos conectar. Revisa tu internet.');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD9E7), Color(0xFFECE0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const NenisMark(size: 132),
          const Positioned(
            top: 18,
            right: 92,
            child: Icon(Symbols.star, color: AppColors.gold, size: 26, fill: 1),
          ),
          const Positioned(
            bottom: 30,
            left: 88,
            child: Icon(
              Symbols.star,
              color: AppColors.lavender,
              size: 20,
              fill: 1,
            ),
          ),
          const Positioned(
            right: 96,
            bottom: 44,
            child: Icon(
              Symbols.favorite,
              color: Color(0xFFFF9EC0),
              size: 22,
              fill: 1,
            ),
          ),
        ],
      ),
    );
  }
}

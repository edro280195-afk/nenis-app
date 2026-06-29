import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/pill_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phone.text.trim();
    if (phone.length < 8) {
      _toast('Escribe tu número de teléfono 🌸');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (mounted) context.go('/otp');
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('No pudimos conectar. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _wordmark(),
                      const SizedBox(height: 4),
                      const _LoginHero(),
                      const SizedBox(height: 6),
                      Text(
                        'Tus compras de los\nlives, en un solo lugar',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Rastrea pedidos, junta puntos y entra a los lives de todas tus tiendas favoritas.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle,
                      ),
                      const SizedBox(height: 22),
                      AppTextField(
                        controller: _phone,
                        prefix: '🇲🇽 +52',
                        hint: '868 145 22 90',
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => _continue(),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          const Icon(Symbols.lock,
                              size: 16, color: AppColors.ink3),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Te mandamos un código por SMS. Sin contraseñas.',
                              style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _loading
                          ? const _LoadingButton()
                          : PillButton(
                              label: 'Continuar',
                              icon: Symbols.arrow_forward,
                              onPressed: _continue,
                            ),
                      const SizedBox(height: 18),
                      _divider(),
                      const SizedBox(height: 18),
                      PillButton(
                        label: 'Entrar con Facebook',
                        icon: Symbols.thumb_up,
                        variant: PillButtonVariant.facebook,
                        onPressed: () => _toast(
                            'Facebook llega pronto. Por ahora entra con tu teléfono 💕'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordmark() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: [AppColors.neni, AppColors.neniDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.brandSmall(AppColors.neniDeep),
          ),
          child: const Icon(Symbols.favorite,
              color: AppColors.surface, size: 26, fill: 1),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            text: "Neni's",
            style: AppTextStyles.h1,
            children: const [
              TextSpan(text: '.', style: TextStyle(color: AppColors.neniDeep)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
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
              Text('Para administradoras y conductores con correo.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12.5)),
              const SizedBox(height: 16),
              AppTextField(
                controller: email,
                prefixIcon: Symbols.mail,
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: pass,
                prefixIcon: Symbols.lock,
                hint: 'Contraseña',
                obscureText: true,
              ),
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
              strokeWidth: 2.5, color: AppColors.surface),
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
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [AppColors.neni, AppColors.neniDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppShadows.brandPrimary(AppColors.neniDeep),
            ),
            child: const Icon(Symbols.shopping_bag,
                color: AppColors.surface, size: 50, fill: 1),
          ),
          const Positioned(
            top: 18,
            right: 92,
            child: Icon(Symbols.star, color: AppColors.gold, size: 26, fill: 1),
          ),
          const Positioned(
            bottom: 30,
            left: 88,
            child:
                Icon(Symbols.star, color: AppColors.lavender, size: 20, fill: 1),
          ),
          const Positioned(
            right: 96,
            bottom: 44,
            child: Icon(Symbols.favorite,
                color: Color(0xFFFF9EC0), size: 22, fill: 1),
          ),
        ],
      ),
    );
  }
}

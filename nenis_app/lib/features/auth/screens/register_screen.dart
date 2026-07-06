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

/// Alta de la compradora: nombre, apellido, correo, teléfono y contraseña.
/// Al enviar, dispara el código de WhatsApp y navega a /confirm.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String email) {
    final at = email.indexOf('@');
    return at > 0 && email.indexOf('.', at) > at + 1 && !email.endsWith('.');
  }

  Future<void> _submit() async {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');

    if (firstName.isEmpty || lastName.isEmpty) {
      _toast('Escribe tu nombre y tu apellido 🌸');
      return;
    }
    if (!_looksLikeEmail(email)) {
      _toast('Escribe un correo válido');
      return;
    }
    if (phone.length < 10) {
      _toast('Escribe tu teléfono a 10 dígitos');
      return;
    }
    if (_password.text.length < 8) {
      _toast('La contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).registerPhone(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            email: email,
            password: _password.text,
          );
      if (mounted) context.go('/confirm');
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
            padding: const EdgeInsets.only(bottom: 28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackIconButton(onPressed: () => context.go('/login')),
                  ),
                  const SizedBox(height: 14),
                  const NenisLogo(markSize: 46, wordmarkSize: 24),
                  const SizedBox(height: 18),
                  Text('Crea tu cuenta', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  Text(
                    'Solo te pediremos tus datos una vez. Confirmamos tu número por WhatsApp.',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _firstName,
                          label: 'Nombre',
                          hint: 'Ana',
                          keyboardType: TextInputType.name,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _lastName,
                          label: 'Apellido',
                          hint: 'López',
                          keyboardType: TextInputType.name,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _email,
                    label: 'Correo',
                    prefixIcon: Symbols.mail,
                    hint: 'tu@correo.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _phone,
                    label: 'Teléfono (WhatsApp)',
                    prefix: '🇲🇽 +52',
                    hint: '868 145 22 90',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _password,
                    label: 'Contraseña',
                    hint: 'Mínimo 8 caracteres',
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 22),
                  _loading
                      ? const _LoadingButton()
                      : PillButton(
                          label: 'Crear cuenta',
                          icon: Symbols.arrow_forward,
                          onPressed: _submit,
                        ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13.5),
                          children: [
                            const TextSpan(text: '¿Ya tienes cuenta? '),
                            TextSpan(
                              text: 'Inicia sesión',
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
                ],
              ),
            ),
          ),
        ),
      ),
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

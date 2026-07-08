import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/legal/legal_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/background.dart';
import '../../../shared/widgets/nenis_logo.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/shake_widget.dart';
import '../widgets/auth_feedback.dart';
import '../widgets/legal_acceptance.dart';

enum LoginRole { client, seller }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _clientPhone = TextEditingController();
  final _clientPassword = TextEditingController();
  final _sellerEmail = TextEditingController();
  final _sellerPassword = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  LoginRole _role = LoginRole.client;
  bool _loading = false;
  bool _facebookLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _clientPhone.addListener(_onInputChanged);
    _clientPassword.addListener(_onInputChanged);
    _sellerEmail.addListener(_onInputChanged);
    _sellerPassword.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _clientPhone.removeListener(_onInputChanged);
    _clientPassword.removeListener(_onInputChanged);
    _sellerEmail.removeListener(_onInputChanged);
    _sellerPassword.removeListener(_onInputChanged);
    _clientPhone.dispose();
    _clientPassword.dispose();
    _sellerEmail.dispose();
    _sellerPassword.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
  }

  bool get _isClientValid {
    final phone = _clientPhone.text.replaceAll(RegExp(r'\D'), '');
    final password = _clientPassword.text;
    return phone.length == 10 && password.isNotEmpty;
  }

  bool get _isSellerValid {
    final email = _sellerEmail.text.trim();
    final password = _sellerPassword.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email) && password.isNotEmpty;
  }

  bool get _isFormValid {
    return _role == LoginRole.client ? _isClientValid : _isSellerValid;
  }

  Future<void> _continue() async {
    if (_loading) return;

    if (_role == LoginRole.client) {
      await _loginClient();
      return;
    }
    await _loginSeller();
  }

  Future<void> _loginClient() async {
    if (_loading) return;
    final phone = _clientPhone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      _setError('Escribe tu teléfono a 10 dígitos.');
      _shakeKey.currentState?.shake();
      return;
    }
    if (_clientPassword.text.isEmpty) {
      _setError('Escribe tu contraseña.');
      _shakeKey.currentState?.shake();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginPhone(phone, _clientPassword.text);
    } on PhoneNotVerifiedException catch (error) {
      if (mounted) {
        showAuthNotification(context, error.message);
        context.go('/confirm');
      }
    } on AuthException catch (error) {
      _setError(error.message);
      _shakeKey.currentState?.shake();
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
      _shakeKey.currentState?.shake();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginSeller() async {
    if (_loading) return;
    final email = _sellerEmail.text.trim();
    final isValidEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!isValidEmail) {
      _setError('Escribe un correo válido.');
      _shakeKey.currentState?.shake();
      return;
    }
    if (_sellerPassword.text.isEmpty) {
      _setError('Escribe tu contraseña.');
      _shakeKey.currentState?.shake();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginEmail(email, _sellerPassword.text);
    } on AuthException catch (error) {
      _setError(error.message);
      _shakeKey.currentState?.shake();
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
      _shakeKey.currentState?.shake();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facebookLogin() async {
    if (_facebookLoading) return;

    final accountType = _role == LoginRole.client
        ? FacebookAccountType.client
        : FacebookAccountType.seller;
    setState(() {
      _facebookLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginFacebook(accountType);
    } on FacebookCancelledException {
      // La usuaria canceló el flujo y permanece en el login.
    } on FacebookProfileRequiredException catch (error) {
      if (mounted) await _completeFacebookProfile(error);
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Ocurrió un problema inesperado. Inténtalo nuevamente.');
    } finally {
      if (mounted) setState(() => _facebookLoading = false);
    }
  }

  Future<void> _completeFacebookProfile(
    FacebookProfileRequiredException draft,
  ) async {
    final needsPhoneVerification = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FacebookProfileSheet(draft: draft),
    );
    if (needsPhoneVerification == true && mounted) {
      context.go('/confirm');
    }
  }

  void _selectRole(LoginRole role) {
    if (_loading || _facebookLoading || role == _role) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _role = role;
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final gradientColor = _role == LoginRole.client
        ? const Color(0xFFFFE6F0)
        : const Color(0xFFF2ECFF);

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -1.0),
            radius: 1.0,
            colors: [gradientColor, AppColors.surfaceCream],
            stops: const [0.0, 1.0],
          ),
        ),
        child: NeniBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 40 : 20,
                    isWide ? 36 : 14,
                    isWide ? 40 : 20,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 980 : 520),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _LoginIntro(role: _role)),
                                const SizedBox(width: 52),
                                SizedBox(
                                  width: 440,
                                  child: ShakeWidget(
                                    key: _shakeKey,
                                    child: _AuthSurface(
                                      role: _role,
                                      loading: _loading,
                                      facebookLoading: _facebookLoading,
                                      errorMessage: _errorMessage,
                                      disableAnimations: disableAnimations,
                                      clientPhone: _clientPhone,
                                      clientPassword: _clientPassword,
                                      sellerEmail: _sellerEmail,
                                      sellerPassword: _sellerPassword,
                                      onRoleChanged: _selectRole,
                                      onContinue: _continue,
                                      onFacebook: _facebookLogin,
                                      isFormValid: _isFormValid,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LoginIntro(compact: true, role: _role),
                                const SizedBox(height: 24),
                                ShakeWidget(
                                  key: _shakeKey,
                                  child: _AuthSurface(
                                    role: _role,
                                    loading: _loading,
                                    facebookLoading: _facebookLoading,
                                    errorMessage: _errorMessage,
                                    disableAnimations: disableAnimations,
                                    clientPhone: _clientPhone,
                                    clientPassword: _clientPassword,
                                    sellerEmail: _sellerEmail,
                                    sellerPassword: _sellerPassword,
                                    onRoleChanged: _selectRole,
                                    onContinue: _continue,
                                    onFacebook: _facebookLogin,
                                    isFormValid: _isFormValid,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro({this.compact = false, required this.role});

  final bool compact;
  final LoginRole role;

  @override
  Widget build(BuildContext context) {
    final isClient = role == LoginRole.client;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          const NenisLogo(markSize: 46, wordmarkSize: 23),
          const SizedBox(height: 18),
        ] else ...[
          const NenisLogo(markSize: 60, wordmarkSize: 28),
          const SizedBox(height: 24),
        ],

        // Ilustración Héroe Dinámica
        Center(
          child: SizedBox(
            height: 140,
            width: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anillo de fondo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isClient
                            ? const Color(0xFFFFE5EE)
                            : const Color(0xFFF2ECFF),
                        isClient
                            ? const Color(0xFFFFD0E2)
                            : const Color(0xFFE6DCFF),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withAlpha(200)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A3A2221),
                        offset: Offset(0, 10),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),

                // Contenedor del ícono principal
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isClient
                          ? [const Color(0xFFFF6F9C), const Color(0xFFE84E83)]
                          : [const Color(0xFF9B7BE0), const Color(0xFF7450A8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isClient
                                    ? const Color(0xFFE84E83)
                                    : const Color(0xFF7450A8))
                                .withAlpha(128),
                        offset: const Offset(0, 10),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      isClient ? Symbols.shopping_bag : Symbols.storefront,
                      key: ValueKey(role),
                      color: Colors.white,
                      size: 32,
                      fill: 1.0,
                    ),
                  ),
                ),

                // Elementos decorativos (sparks/hearts)
                Positioned(
                  top: 15,
                  right: 35,
                  child: Icon(
                    Symbols.star,
                    color: isClient
                        ? const Color(0xFFF3B341)
                        : const Color(0xFFFFB703),
                    size: 20,
                    fill: 1.0,
                  ),
                ),
                Positioned(
                  bottom: 15,
                  left: 35,
                  child: Icon(
                    Symbols.star,
                    color: isClient
                        ? const Color(0xFF9B7BE0)
                        : const Color(0xFFFF6F9C),
                    size: 16,
                    fill: 1.0,
                  ),
                ),
                if (isClient)
                  const Positioned(
                    top: 35,
                    left: 40,
                    child: Icon(
                      Symbols.favorite,
                      color: Color(0xFFFF9EC0),
                      size: 18,
                      fill: 1.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Textos Dinámicos
        Center(
          child: Text(
            isClient ? 'Compra en tus Lives' : 'Gestiona tu Tienda',
            textAlign: TextAlign.center,
            style: AppTextStyles.display.copyWith(
              fontSize: compact ? 26 : 32,
              height: 1.12,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              isClient
                  ? 'Rastrea pedidos, junta puntos y entra a los lives de tus tiendas favoritas.'
                  : 'Controla inventario, recibe pedidos y transmite lives para tus clientas.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontSize: compact ? 13 : 14.5,
                color: AppColors.ink2,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthSurface extends StatelessWidget {
  const _AuthSurface({
    required this.role,
    required this.loading,
    required this.facebookLoading,
    required this.errorMessage,
    required this.disableAnimations,
    required this.clientPhone,
    required this.clientPassword,
    required this.sellerEmail,
    required this.sellerPassword,
    required this.onRoleChanged,
    required this.onContinue,
    required this.onFacebook,
    required this.isFormValid,
  });

  final LoginRole role;
  final bool loading;
  final bool facebookLoading;
  final String? errorMessage;
  final bool disableAnimations;
  final TextEditingController clientPhone;
  final TextEditingController clientPassword;
  final TextEditingController sellerEmail;
  final TextEditingController sellerPassword;
  final ValueChanged<LoginRole> onRoleChanged;
  final VoidCallback onContinue;
  final VoidCallback onFacebook;
  final bool isFormValid;

  @override
  Widget build(BuildContext context) {
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        border: Border.all(color: AppColors.line, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cómo quieres entrar?',
              style: AppTextStyles.h2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 5),
            Text(
              'Puedes volver y cambiar de opción en cualquier momento.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            _RoleSelector(
              selectedRole: role,
              duration: duration,
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 20),
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
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: role == LoginRole.client
                  ? _ClientLoginForm(
                      key: const ValueKey(LoginRole.client),
                      phone: clientPhone,
                      password: clientPassword,
                      loading: loading,
                      facebookLoading: facebookLoading,
                      errorMessage: errorMessage,
                      onContinue: onContinue,
                      onFacebook: onFacebook,
                      isFormValid: isFormValid,
                    )
                  : _SellerLoginForm(
                      key: const ValueKey(LoginRole.seller),
                      email: sellerEmail,
                      password: sellerPassword,
                      loading: loading,
                      facebookLoading: facebookLoading,
                      errorMessage: errorMessage,
                      onContinue: onContinue,
                      onFacebook: onFacebook,
                      isFormValid: isFormValid,
                    ),
            ),
            const SizedBox(height: 18),
            const LegalLinksCaption(),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.duration,
    required this.onChanged,
  });

  final LoginRole selectedRole;
  final Duration duration;
  final ValueChanged<LoginRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.segTrack,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleOption(
              key: const Key('login-role-client'),
              label: 'Clienta',
              icon: Symbols.shopping_bag,
              role: LoginRole.client,
              selected: selectedRole == LoginRole.client,
              duration: duration,
              onTap: () => onChanged(LoginRole.client),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _RoleOption(
              key: const Key('login-role-seller'),
              label: 'Vendedora',
              icon: Symbols.storefront,
              role: LoginRole.seller,
              selected: selectedRole == LoginRole.seller,
              duration: duration,
              onTap: () => onChanged(LoginRole.seller),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    super.key,
    required this.label,
    required this.icon,
    required this.role,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final LoginRole role;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = role == LoginRole.client
        ? AppColors.neniDeep
        : AppColors.lavender;
    final selectedBackground = role == LoginRole.client
        ? const Color(0xFFFFE9F0)
        : const Color(0xFFF2ECFF);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Entrar como $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? selectedBackground : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: selected
                  ? Border.all(color: accent.withValues(alpha: 0.16))
                  : null,
              boxShadow: selected ? AppShadows.small : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? accent : AppColors.ink2,
                  fill: selected ? 1 : 0,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: selected ? AppColors.ink : AppColors.ink2,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
}

class _ClientLoginForm extends StatelessWidget {
  const _ClientLoginForm({
    super.key,
    required this.phone,
    required this.password,
    required this.loading,
    required this.facebookLoading,
    required this.errorMessage,
    required this.onContinue,
    required this.onFacebook,
    required this.isFormValid,
  });

  final TextEditingController phone;
  final TextEditingController password;
  final bool loading;
  final bool facebookLoading;
  final String? errorMessage;
  final VoidCallback onContinue;
  final VoidCallback onFacebook;
  final bool isFormValid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoleHeading(
          icon: Symbols.local_mall,
          iconColor: AppColors.neniDeep,
          iconBackground: const Color(0xFFFFE5EE),
          title: 'Tu espacio de compras',
          subtitle: 'Revisa pedidos, puntos y tus tiendas favoritas.',
        ),
        const SizedBox(height: 18),
        AppTextField(
          key: const Key('client-phone-field'),
          controller: phone,
          label: 'Teléfono',
          prefix: '🇲🇽 +52',
          hint: '868 145 22 90',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 13),
        PasswordField(
          key: const Key('client-password-field'),
          controller: password,
          label: 'Contraseña',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onContinue(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('forgot-password-client'),
            onPressed: loading ? null : () => context.go('/forgot-password'),
            child: const Text('Olvidé mi contraseña'),
          ),
        ),
        if (errorMessage != null) ...[
          AuthFeedbackBanner(
            key: const Key('login-error'),
            message: errorMessage!,
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 4),
        _PrimaryAction(
          label: 'Entrar a mis compras',
          icon: Symbols.arrow_forward,
          role: LoginRole.client,
          loading: loading,
          onPressed: loading ? null : onContinue,
        ),
        const SizedBox(height: 13),
        Center(
          child: TextButton(
            onPressed: loading
                ? null
                : () => context.go('/register?role=client'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neniDeep,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text.rich(
              TextSpan(
                text: '¿Eres nueva? ',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'Crea tu cuenta',
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.neniDeep,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        // Login passwordless (telefono + codigo, sin contrasena).
        Center(
          child: TextButton(
            onPressed: loading ? null : () => context.go('/login-otp'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.neniDeep,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text.rich(
              TextSpan(
                text: '¿Sin contraseña? ',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'Entrar con código',
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.neniDeep,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _OrDivider(),
        const SizedBox(height: 14),
        _FacebookButton(
          loading: facebookLoading,
          onPressed: loading || facebookLoading ? null : onFacebook,
        ),
      ],
    );
  }
}

class _SellerLoginForm extends StatelessWidget {
  const _SellerLoginForm({
    super.key,
    required this.email,
    required this.password,
    required this.loading,
    required this.facebookLoading,
    required this.errorMessage,
    required this.onContinue,
    required this.onFacebook,
    required this.isFormValid,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final bool facebookLoading;
  final String? errorMessage;
  final VoidCallback onContinue;
  final VoidCallback onFacebook;
  final bool isFormValid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RoleHeading(
          icon: Symbols.storefront,
          iconColor: Color(0xFF7450A8),
          iconBackground: Color(0xFFF0E8FF),
          title: 'Tu espacio de ventas',
          subtitle: 'Entra con el correo que usas para administrar tu tienda.',
        ),
        const SizedBox(height: 18),
        AppTextField(
          key: const Key('seller-email-field'),
          controller: email,
          label: 'Correo',
          prefixIcon: Symbols.mail,
          hint: 'hola@tutienda.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          autocorrect: false,
          enableSuggestions: false,
        ),
        const SizedBox(height: 13),
        PasswordField(
          key: const Key('seller-password-field'),
          controller: password,
          label: 'Contraseña',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onContinue(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('forgot-password-seller'),
            onPressed: loading ? null : () => context.go('/forgot-password'),
            child: const Text('Olvidé mi contraseña'),
          ),
        ),
        if (errorMessage != null) ...[
          AuthFeedbackBanner(
            key: const Key('login-error'),
            message: errorMessage!,
          ),
          const SizedBox(height: 14),
        ] else
          const SizedBox(height: 4),
        _PrimaryAction(
          label: 'Entrar a mi tienda',
          icon: Symbols.arrow_forward,
          role: LoginRole.seller,
          loading: loading,
          onPressed: loading ? null : onContinue,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            key: const Key('seller-register-link'),
            onPressed: loading
                ? null
                : () => context.go('/register?role=seller'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7450A8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text.rich(
              TextSpan(
                text: 'Aun no tienes tienda? ',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'Crea tu cuenta de vendedora',
                    style: AppTextStyles.subtitle.copyWith(
                      color: const Color(0xFF7450A8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2FF),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Symbols.verified_user,
                color: Color(0xFF7450A8),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conservamos tu negocio y los permisos que ya tienes asignados.',
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.ink2,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _OrDivider(),
        const SizedBox(height: 14),
        _FacebookButton(
          loading: facebookLoading,
          onPressed: loading || facebookLoading ? null : onFacebook,
        ),
      ],
    );
  }
}

class _FacebookProfileSheet extends ConsumerStatefulWidget {
  const _FacebookProfileSheet({required this.draft});

  final FacebookProfileRequiredException draft;

  @override
  ConsumerState<_FacebookProfileSheet> createState() =>
      _FacebookProfileSheetState();
}

class _FacebookProfileSheetState extends ConsumerState<_FacebookProfileSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _businessName;
  late final TextEditingController _city;
  late final TextEditingController _existingPassword;

  late bool _requiresExistingPassword;
  bool _acceptedLegal = false;
  bool _saving = false;
  String? _error;

  bool get _isSeller => widget.draft.accountType == FacebookAccountType.seller;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.draft.firstName);
    _lastName = TextEditingController(text: widget.draft.lastName);
    _email = TextEditingController(text: widget.draft.email);
    _phone = TextEditingController(text: widget.draft.phone);
    _businessName = TextEditingController();
    _city = TextEditingController();
    _existingPassword = TextEditingController();
    _requiresExistingPassword = widget.draft.requiresExistingPassword;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _businessName.dispose();
    _city.dispose();
    _existingPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final businessName = _businessName.text.trim();
    final city = _city.text.trim();
    final existingPassword = _existingPassword.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Escribe tu nombre y apellido.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    if (phone.length != 10) {
      setState(() => _error = 'Escribe tu teléfono a 10 dígitos.');
      return;
    }
    if (_isSeller && businessName.isEmpty) {
      setState(() => _error = 'Escribe el nombre de tu negocio.');
      return;
    }
    if (_requiresExistingPassword && existingPassword.isEmpty) {
      setState(() => _error = 'Escribe la contraseña actual de tu cuenta.');
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
      _saving = true;
      _error = null;
    });

    final profile = FacebookProfileCompletion(
      accountType: widget.draft.accountType,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      businessName: _isSeller ? businessName : null,
      city: _isSeller && city.isNotEmpty ? city : null,
      existingPassword: _requiresExistingPassword ? existingPassword : null,
      acceptedLegal: _acceptedLegal,
      legalVersion: LegalConfig.currentVersion,
    );

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeFacebookProfile(profile);
      if (mounted) Navigator.of(context).pop(false);
    } on FacebookPhoneVerificationRequiredException {
      if (mounted) Navigator.of(context).pop(true);
    } on FacebookProfileRequiredException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _requiresExistingPassword = error.requiresExistingPassword;
        _error = error.message;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos conectar. Revisa tu internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final role = _isSeller ? LoginRole.seller : LoginRole.client;
    final accent = _isSeller ? const Color(0xFF7450A8) : AppColors.neniDeep;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, bottomInset + 22),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Completa tu cuenta',
                        style: AppTextStyles.h1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Text(
                        _isSeller ? 'Vendedora' : 'Clienta',
                        style: AppTextStyles.subtitle.copyWith(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _isSeller
                      ? 'Facebook ya confirmó tu identidad. Agrega los datos de tu tienda para dejarla lista.'
                      : 'Facebook ya confirmó tu identidad. Solo necesitamos los datos que usamos para tus compras.',
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  key: const Key('facebook-first-name-field'),
                  controller: _firstName,
                  label: 'Nombre',
                  prefixIcon: Symbols.person,
                  hint: 'Tu nombre',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                ),
                const SizedBox(height: 13),
                AppTextField(
                  key: const Key('facebook-last-name-field'),
                  controller: _lastName,
                  label: 'Apellido',
                  prefixIcon: Symbols.person,
                  hint: 'Tu apellido',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                ),
                const SizedBox(height: 13),
                AppTextField(
                  key: const Key('facebook-email-field'),
                  controller: _email,
                  label: 'Correo',
                  prefixIcon: Symbols.mail,
                  hint: 'hola@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 13),
                AppTextField(
                  key: const Key('facebook-phone-field'),
                  controller: _phone,
                  label: 'Teléfono',
                  prefix: '🇲🇽 +52',
                  hint: '868 145 22 90',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                if (_isSeller) ...[
                  const SizedBox(height: 13),
                  AppTextField(
                    key: const Key('facebook-business-name-field'),
                    controller: _businessName,
                    label: 'Nombre de tu negocio',
                    prefixIcon: Symbols.storefront,
                    hint: 'Ej. Regi Bazar',
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.organizationName],
                  ),
                  const SizedBox(height: 13),
                  AppTextField(
                    key: const Key('facebook-city-field'),
                    controller: _city,
                    label: 'Ciudad (opcional)',
                    prefixIcon: Symbols.location_on,
                    hint: 'Ej. Matamoros',
                    textInputAction: _requiresExistingPassword
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: const [AutofillHints.addressCity],
                    onSubmitted: (_) {
                      if (!_requiresExistingPassword) _submit();
                    },
                  ),
                ],
                if (_requiresExistingPassword) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5E6),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Text(
                      'Ya existe una cuenta con ese correo o teléfono. Escribe su contraseña actual para vincular Facebook sin duplicarla.',
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.ink2,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  PasswordField(
                    key: const Key('facebook-existing-password-field'),
                    controller: _existingPassword,
                    label: 'Contraseña actual',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('facebook-forgot-password'),
                      onPressed: _saving
                          ? null
                          : () {
                              final router = GoRouter.of(context);
                              Navigator.of(context).pop();
                              router.go('/forgot-password');
                            },
                      child: const Text('No recuerdo mi contraseña'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                LegalAcceptanceCheckbox(
                  key: const Key('facebook-legal-checkbox'),
                  value: _acceptedLegal,
                  enabled: !_saving,
                  onChanged: (value) => setState(() {
                    _acceptedLegal = value;
                    if (value) _error = null;
                  }),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  AuthFeedbackBanner(
                    key: const Key('facebook-profile-error'),
                    message: _error!,
                  ),
                ],
                const SizedBox(height: 20),
                _PrimaryAction(
                  label: _requiresExistingPassword
                      ? 'Vincular y continuar'
                      : 'Guardar y continuar',
                  icon: Symbols.arrow_forward,
                  role: role,
                  loading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
                const SizedBox(height: 12),
                Text(
                  'Después confirmaremos tu teléfono por WhatsApp. Nunca publicaremos en Facebook.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.ink3,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleHeading extends StatelessWidget {
  const _RoleHeading({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Icon(icon, color: iconColor, size: 22, fill: 1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.role,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final LoginRole role;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background = role == LoginRole.client
        ? AppColors.neniDeep
        : AppColors.ink;
    final disabled = onPressed == null;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled && !loading ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadii.pillRadius,
            child: Ink(
              height: 56,
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadii.pillRadius,
                boxShadow: disabled
                    ? const []
                    : AppShadows.brandPrimary(background),
              ),
              child: Center(
                child: loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.surface,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: AppTextStyles.button),
                            const SizedBox(width: 9),
                            Icon(icon, color: AppColors.surface, size: 21),
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
}

class _FacebookButton extends StatelessWidget {
  const _FacebookButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: AppTextStyles.button.copyWith(
          color: AppColors.ink,
          fontSize: 14,
        ),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: AppColors.facebook,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.facebook,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      'f',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.surface,
                        fontSize: 17,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continuar con Facebook',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.ink,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o continúa con',
            style: AppTextStyles.subtitle.copyWith(fontSize: 10.5),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: AppRadii.pillRadius,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
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
  final _sellerPhone = TextEditingController();
  final _sellerPassword = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();

  LoginRole _role = LoginRole.client;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _clientPhone.addListener(_onInputChanged);
    _clientPassword.addListener(_onInputChanged);
    _sellerPhone.addListener(_onInputChanged);
    _sellerPassword.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _clientPhone.removeListener(_onInputChanged);
    _clientPassword.removeListener(_onInputChanged);
    _sellerPhone.removeListener(_onInputChanged);
    _sellerPassword.removeListener(_onInputChanged);
    _clientPhone.dispose();
    _clientPassword.dispose();
    _sellerPhone.dispose();
    _sellerPassword.dispose();
    super.dispose();
  }

  void _onInputChanged() => setState(() {});

  bool get _isClientValid {
    final phone = _clientPhone.text.replaceAll(RegExp(r'\D'), '');
    return phone.length == 10 && _clientPassword.text.isNotEmpty;
  }

  bool get _isSellerValid {
    final phone = _sellerPhone.text.replaceAll(RegExp(r'\D'), '');
    return phone.length == 10 && _sellerPassword.text.isNotEmpty;
  }

  bool get _isFormValid =>
      _role == LoginRole.client ? _isClientValid : _isSellerValid;

  Future<void> _continue() async {
    if (_loading) return;
    if (_role == LoginRole.client) {
      await _loginClient();
    } else {
      await _loginSeller();
    }
  }

  Future<void> _loginClient() async {
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
    final phone = _sellerPhone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      _setError('Escribe tu teléfono a 10 dígitos.');
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
          .loginPhone(phone, _sellerPassword.text);
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

  void _selectRole(LoginRole role) {
    if (_loading || role == _role) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _role = role;
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    if (mounted) setState(() => _errorMessage = message);
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
            center: const Alignment(0, -1),
            radius: 1,
            colors: [gradientColor, AppColors.surfaceCream],
          ),
        ),
        child: NeniBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final surface = ShakeWidget(
                  key: _shakeKey,
                  child: _AuthSurface(
                    role: _role,
                    loading: _loading,
                    errorMessage: _errorMessage,
                    disableAnimations: disableAnimations,
                    clientPhone: _clientPhone,
                    clientPassword: _clientPassword,
                    sellerPhone: _sellerPhone,
                    sellerPassword: _sellerPassword,
                    onRoleChanged: _selectRole,
                    onContinue: _continue,
                    isFormValid: _isFormValid,
                  ),
                );
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
                                SizedBox(width: 440, child: surface),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LoginIntro(compact: true, role: _role),
                                const SizedBox(height: 12),
                                surface,
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
        NenisLogo(markSize: compact ? 38 : 60, wordmarkSize: compact ? 20 : 28),
        SizedBox(height: compact ? 18 : 30),
        Icon(
          isClient ? Symbols.shopping_bag : Symbols.storefront,
          color: isClient ? AppColors.neniDeep : AppColors.lavender,
          size: compact ? 44 : 72,
          fill: 1,
        ),
        const SizedBox(height: 14),
        Text(
          isClient ? 'Compra en tus Lives' : 'Gestiona tu Tienda',
          textAlign: TextAlign.center,
          style: AppTextStyles.display.copyWith(fontSize: compact ? 22 : 32),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            isClient
                ? 'Rastrea pedidos, junta puntos y entra a las tiendas que te gustan.'
                : 'Controla inventario, recibe pedidos y administra tu tienda.',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: compact ? 13 : 14.5,
              color: AppColors.ink2,
              height: 1.4,
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
    required this.errorMessage,
    required this.disableAnimations,
    required this.clientPhone,
    required this.clientPassword,
    required this.sellerPhone,
    required this.sellerPassword,
    required this.onRoleChanged,
    required this.onContinue,
    required this.isFormValid,
  });

  final LoginRole role;
  final bool loading;
  final String? errorMessage;
  final bool disableAnimations;
  final TextEditingController clientPhone;
  final TextEditingController clientPassword;
  final TextEditingController sellerPhone;
  final TextEditingController sellerPassword;
  final ValueChanged<LoginRole> onRoleChanged;
  final VoidCallback onContinue;
  final bool isFormValid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elige tu cuenta',
            style: AppTextStyles.h2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 5),
          Text(
            'Clienta para comprar. Vendedora para administrar.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          _RoleSelector(
            selectedRole: role,
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            onChanged: onRoleChanged,
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 260),
            child: role == LoginRole.client
                ? _ClientLoginForm(
                    key: const ValueKey(LoginRole.client),
                    phone: clientPhone,
                    password: clientPassword,
                    loading: loading,
                    errorMessage: errorMessage,
                    onContinue: onContinue,
                  )
                : _SellerLoginForm(
                    key: const ValueKey(LoginRole.seller),
                    phone: sellerPhone,
                    password: sellerPassword,
                    loading: loading,
                    errorMessage: errorMessage,
                    onContinue: onContinue,
                  ),
          ),
          const SizedBox(height: 18),
          const LegalLinksCaption(),
        ],
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
            height: 48,
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.10) : null,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: selected
                  ? Border.all(color: accent.withValues(alpha: 0.18))
                  : null,
              boxShadow: selected ? AppShadows.small : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? accent : AppColors.ink2),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
    required this.errorMessage,
    required this.onContinue,
  });

  final TextEditingController phone;
  final TextEditingController password;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RoleHeading(
          icon: Symbols.local_mall,
          iconColor: AppColors.neniDeep,
          iconBackground: Color(0xFFFFE5EE),
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
        OutlinedButton(
          onPressed: loading ? null : () => context.go('/register?role=client'),
          child: const Text('Crear cuenta de clienta'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: loading ? null : () => context.go('/login-otp'),
          child: const Text('¿Sin contraseña? Entrar con código'),
        ),
      ],
    );
  }
}

class _SellerLoginForm extends StatelessWidget {
  const _SellerLoginForm({
    super.key,
    required this.phone,
    required this.password,
    required this.loading,
    required this.errorMessage,
    required this.onContinue,
  });

  final TextEditingController phone;
  final TextEditingController password;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onContinue;

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
          subtitle: 'Entra con el teléfono que protege tu cuenta.',
        ),
        const SizedBox(height: 18),
        AppTextField(
          key: const Key('seller-phone-field'),
          controller: phone,
          label: 'Teléfono',
          prefix: '🇲🇽 +52',
          hint: '868 145 22 90',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
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
        OutlinedButton(
          key: const Key('seller-register-link'),
          onPressed: loading ? null : () => context.go('/register?role=seller'),
          child: const Text('Crear cuenta de vendedora'),
        ),
      ],
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Icon(icon, color: iconColor, fill: 1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h2.copyWith(fontSize: 17)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 12),
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
    final color = role == LoginRole.client
        ? AppColors.neniDeep
        : const Color(0xFF7450A8);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(50),
        shape: const StadiumBorder(),
      ),
    );
  }
}

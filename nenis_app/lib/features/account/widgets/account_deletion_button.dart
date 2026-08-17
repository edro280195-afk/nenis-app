import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/pill_button.dart';

/// Acción común para solicitar la eliminación de la cuenta desde cualquier rol.
class AccountDeletionButton extends StatelessWidget {
  const AccountDeletionButton({super.key, required this.onConfirm});

  final Future<void> Function() onConfirm;

  Future<void> _handleTap(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Esta acción es permanente: elimina tu identidad, sesiones, tokens y datos personales. Los historiales operativos necesarios pueden conservarse anonimizados. No podrás recuperar la cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar cuenta',
              style: TextStyle(
                color: AppColors.liveRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await onConfirm();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: PillButton(
        label: 'Eliminar mi cuenta',
        icon: Symbols.delete_forever,
        variant: PillButtonVariant.ghost,
        onPressed: () => _handleTap(context),
      ),
    );
  }
}

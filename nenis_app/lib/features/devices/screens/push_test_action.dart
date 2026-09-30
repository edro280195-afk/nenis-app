import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_service.dart';
import '../../../shared/widgets/premium_toast.dart';

/// Registra este teléfono y manda una notificación de prueba a la propia cuenta.
/// Avisa en cada paso (permiso, token, servidor) para que la usuaria sepa qué
/// falta si no llega, en vez de fallar en silencio. Solo muestra el resultado:
/// un aviso previo de "probando" se encimaba con él.
Future<void> runPushSelfTest(BuildContext context, WidgetRef ref) async {
  final outcome = await ref.read(pushServiceProvider).runSelfTest();
  if (!context.mounted) return;
  context.showPremiumToast(
    outcome.message,
    type: outcome.ok ? PremiumToastType.success : PremiumToastType.error,
  );
}

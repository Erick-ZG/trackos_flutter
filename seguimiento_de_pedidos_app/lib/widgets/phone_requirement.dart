import 'package:flutter/material.dart';

import '../screens/phone_edit_screen.dart';
import '../services/app_service.dart';
import '../utils/phone_utils.dart';

Future<bool> ensureContactPhone(BuildContext context) async {
  final user = await AppService().refreshCurrentUser();
  if (!context.mounted) return false;
  if (PhoneUtils.isValid(user.phone)) return true;

  final shouldEdit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Completa tu teléfono'),
      content: const Text(
        'Agrega un celular válido a tu perfil para coordinar la entrega '
        'antes de continuar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Completar teléfono'),
        ),
      ],
    ),
  );
  if (!context.mounted || shouldEdit != true) return false;

  final saved = await PhoneEditScreen.open(context);
  if (context.mounted && saved) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teléfono actualizado. Vuelve a intentar la operación.'),
      ),
    );
  }
  return false;
}

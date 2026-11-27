import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../utils/phone_utils.dart';

class PhoneEditScreen extends StatefulWidget {
  const PhoneEditScreen({super.key});

  static Future<bool> open(BuildContext context) async {
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PhoneEditScreen()),
        ) ??
        false;
  }

  @override
  State<PhoneEditScreen> createState() => _PhoneEditScreenState();
}

class _PhoneEditScreenState extends State<PhoneEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(
    text: AppService().currentUser?.phone ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AppService().updatePhone(_phoneController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teléfono de contacto')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Tu teléfono permite coordinar la entrega de tus pedidos. '
                  'Se comparte con la otra persona cuando el reparto está asignado.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_saving,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Celular de Perú',
                    hintText: '999 000 001',
                    helperText:
                        '9 dígitos que empiecen por 9. Prefijo +51 opcional.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) =>
                      PhoneUtils.validate(value, isRequired: true),
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando...' : 'Guardar teléfono'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
